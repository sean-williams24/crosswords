import StoreKit

@MainActor
final class StoreService: ObservableObject {
    private let logger = StoreLogger()

    // MARK: - Product IDs
    static let monthlyID = "com.backword.monthlypro"
    static let annualID = "com.backword.annualpro"
    private static let productIDs = [monthlyID, annualID]

    // MARK: - Published State
    @Published private(set) var products: [Product] = []
    @Published private(set) var isProUser = false
    @Published private(set) var subscriptionStatusLoaded = false
    @Published private(set) var purchaseInProgress = false

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var annualProduct: Product? { products.first { $0.id == Self.annualID } }

    #if DEBUG
    var hasDebugProOverride: Bool { debugProOverride != nil }
    var debugProOverrideValue: Bool? { debugProOverride }
    @Published private(set) var simulateNextPurchasePending = false
    @Published private(set) var simulateNextRestoreOutcome: StoreRestoreOutcome?
    @Published private(set) var isDumpingStoreKitEntitlements = false
    @Published private(set) var storeKitEntitlementDiagnosticSummary: String?
    #endif

    private var transactionListener: Task<Void, Never>?
    private var subscriptionExpirationRefreshTask: Task<Void, Never>?

    // MARK: - Init
    init() {
        startTransactionListener()

        #if DEBUG
        if let override = UserDefaults.standard.object(forKey: Self.debugProOverrideKey) as? Bool {
            debugProOverride = override
            isProUser = override
            subscriptionStatusLoaded = true
        }
        #endif

        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadProducts() }
                group.addTask { await self.updateSubscriptionStatus() }
            }
        }
    }

    deinit {
        transactionListener?.cancel()
        subscriptionExpirationRefreshTask?.cancel()
    }

    var annualSavings: String? {
        guard let monthlyProduct, let annualProduct else { return nil }
        let monthlyPrice = NSDecimalNumber(decimal: monthlyProduct.price).doubleValue
        let annualPrice = NSDecimalNumber(decimal: annualProduct.price).doubleValue

        let totalMonthlyCost = monthlyPrice * 12
        let savingsPercent = ((totalMonthlyCost - annualPrice) / totalMonthlyCost) * 100
        let savingsPercentString = String(format: "%.0f%%", savingsPercent)
        return "Save \(savingsPercentString)"
    }

    // MARK: - Load Products
    func loadProducts() async {
        logger.productsLoadRequested(productIDs: Self.productIDs)
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
            logger.productsLoaded(
                products.map { StoreLogger.ProductSnapshot(id: $0.id) },
                requestedProductIDs: Self.productIDs
            )
        } catch {
            logger.productsLoadFailed(error)
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async throws -> StorePurchaseOutcome {
        logger.purchaseRequested(productID: product.id)
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        #if DEBUG
        if let simulatedOutcome = Self.debugSimulatedPurchaseOutcome(
            simulateNextPurchasePending: simulateNextPurchasePending
        ) {
            simulateNextPurchasePending = false
            logger.purchaseCompleted(productID: product.id, result: simulatedOutcome)
            return simulatedOutcome
        }
        #endif

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            logger.purchaseFailed(productID: product.id, error: error)
            throw error
        }

        switch result {
        case .success(let verification):
            let transaction: Transaction
            do {
                transaction = try checkVerified(verification)
            } catch {
                logger.purchaseFailed(productID: product.id, error: error)
                throw error
            }

            if grantsProAccess(transaction) {
                isProUser = true
                scheduleSubscriptionExpirationRefresh(
                    nextExpirationDate: transaction.expirationDate,
                    source: "purchase"
                )
            } else {
                await updateSubscriptionStatus(source: "purchase")
            }
            await transaction.finish()
            guard isProUser else {
                logger.purchaseDidNotUnlockPro(productID: product.id)
                throw StoreError.purchaseDidNotUnlockPro
            }
            logger.purchaseCompleted(productID: product.id, result: .purchased)
            return .purchased

        case .userCancelled:
            logger.purchaseCompleted(productID: product.id, result: .cancelled)
            return .cancelled

        case .pending:
            logger.purchaseCompleted(productID: product.id, result: .pending)
            return .pending

        @unknown default:
            logger.purchaseCompleted(productID: product.id, result: .pending)
            return .pending
        }
    }

    // MARK: - Restore
    func restorePurchases() async throws -> StoreRestoreOutcome {
        logger.restoreRequested(source: "user")

        #if DEBUG
        if let simulatedOutcome = simulateNextRestoreOutcome {
            simulateNextRestoreOutcome = nil
            if simulatedOutcome == .restored {
                isProUser = true
            }
            logger.restoreCompleted(simulatedOutcome, source: "debug_simulated")
            return simulatedOutcome
        }

        if debugProOverride != nil {
            do {
                try await AppStore.sync()
            } catch {
                logger.restoreFailed(source: "debug_override_sync", error: error)
                throw error
            }
            await updateSubscriptionStatus(source: "debug_override_restore")
            let outcome: StoreRestoreOutcome = isProUser ? .restored : .notFound
            logger.restoreCompleted(outcome, source: "debug_override_sync")
            return outcome
        }
        #endif

        if await refreshProStatusFromCurrentEntitlements(source: "restore_before_sync") {
            logger.restoreCompleted(.restored, source: "current_entitlements")
            return .restored
        }

        do {
            try await AppStore.sync()
        } catch {
            logger.restoreFailed(source: "app_store_sync", error: error)
            throw error
        }

        let outcome: StoreRestoreOutcome = await refreshProStatusFromCurrentEntitlements(source: "restore_after_sync") ? .restored : .notFound
        logger.restoreCompleted(outcome, source: "app_store_sync")
        return outcome
    }

    // MARK: - Subscription Status
    func updateSubscriptionStatus(source: String = "manual") async {
        #if DEBUG
        if let debugProOverride {
            isProUser = debugProOverride
            subscriptionStatusLoaded = true
            logger.subscriptionStatusRefreshCompleted(
                source: "\(source):debug_override",
                entitlementCount: 0,
                proEntitlementCount: debugProOverride ? 1 : 0,
                unverifiedCount: 0,
                isProUser: isProUser
            )
            return
        }
        #endif

        await refreshProStatusFromCurrentEntitlements(source: source)
    }

    // MARK: - Helpers
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func grantsProAccess(_ transaction: Transaction) -> Bool {
        Self.grantsProAccess(
            productID: transaction.productID,
            revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate,
            now: Date()
        )
    }

    @discardableResult
    private func refreshProStatusFromCurrentEntitlements(source: String) async -> Bool {
        logger.subscriptionStatusRefreshStarted(source: source)
        var hasActiveSubscription = false
        var entitlementCount = 0
        var proEntitlementCount = 0
        var unverifiedCount = 0
        var proEntitlements: [ProEntitlementSnapshot] = []

        for await result in Transaction.currentEntitlements {
            entitlementCount += 1

            switch result {
            case .verified(let transaction):
                let entitlement = ProEntitlementSnapshot(
                    productID: transaction.productID,
                    revocationDate: transaction.revocationDate,
                    expirationDate: transaction.expirationDate
                )
                proEntitlements.append(entitlement)

                if Self.grantsProAccess(
                    productID: entitlement.productID,
                    revocationDate: entitlement.revocationDate,
                    expirationDate: entitlement.expirationDate
                ) {
                    proEntitlementCount += 1
                    hasActiveSubscription = true
                }

            case .unverified:
                unverifiedCount += 1
            }
        }

        isProUser = hasActiveSubscription
        subscriptionStatusLoaded = true
        scheduleSubscriptionExpirationRefresh(
            nextExpirationDate: Self.nextProExpiration(from: proEntitlements),
            source: source
        )
        logger.subscriptionStatusRefreshCompleted(
            source: source,
            entitlementCount: entitlementCount,
            proEntitlementCount: proEntitlementCount,
            unverifiedCount: unverifiedCount,
            isProUser: isProUser
        )
        return hasActiveSubscription
    }

    private func scheduleSubscriptionExpirationRefresh(nextExpirationDate: Date?, source: String) {
        subscriptionExpirationRefreshTask?.cancel()

        guard let nextExpirationDate else { return }

        let delay = max(0, nextExpirationDate.timeIntervalSinceNow + 1)
        subscriptionExpirationRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.updateSubscriptionStatus(source: "\(source):expiration")
        }
    }

    static func grantsProAccess(
        productID: String,
        revocationDate: Date?,
        expirationDate: Date?,
        now: Date = Date()
    ) -> Bool {
        guard productID == monthlyID || productID == annualID else { return false }
        guard revocationDate == nil else { return false }
        guard expirationDate.map({ $0 > now }) ?? true else { return false }
        return true
    }

    static func nextProExpiration(
        from entitlements: [ProEntitlementSnapshot],
        now: Date = Date()
    ) -> Date? {
        entitlements
            .filter {
                grantsProAccess(
                    productID: $0.productID,
                    revocationDate: $0.revocationDate,
                    expirationDate: $0.expirationDate,
                    now: now
                )
            }
            .compactMap(\.expirationDate)
            .min()
    }

    #if DEBUG
    static func debugEffectiveProStatus(
        storeKitStatus: Bool,
        override: Bool?
    ) -> Bool {
        override ?? storeKitStatus
    }

    static func debugSimulatedPurchaseOutcome(
        simulateNextPurchasePending: Bool
    ) -> StorePurchaseOutcome? {
        simulateNextPurchasePending ? .pending : nil
    }

    static func debugSimulatedRestoreOutcome(
        simulateNextRestoreOutcome: StoreRestoreOutcome?
    ) -> StoreRestoreOutcome? {
        simulateNextRestoreOutcome
    }

    static func debugEntitlementDiagnosticSummary(
        totalCount: Int,
        proGrantingCount: Int,
        unverifiedCount: Int
    ) -> String {
        if totalCount == 0 {
            return "No current entitlements returned."
        }

        let entitlementText = totalCount == 1 ? "entitlement" : "entitlements"
        let proText = proGrantingCount == 1 ? "grants" : "grant"
        let unverifiedText = unverifiedCount == 1 ? "unverified" : "unverified"
        return "\(totalCount) current \(entitlementText); \(proGrantingCount) \(proText) Pro; \(unverifiedCount) \(unverifiedText)."
    }
    #endif

    // MARK: - Debug
    #if DEBUG
    private static let debugProOverrideKey = "debug_isProUser"
    @Published private var debugProOverride: Bool?

    func setDebugProUser(_ value: Bool) {
        debugProOverride = value
        isProUser = value
        UserDefaults.standard.set(value, forKey: Self.debugProOverrideKey)
        logger.debugOverrideChanged(value)
    }

    func clearDebugProOverride() {
        debugProOverride = nil
        subscriptionStatusLoaded = false
        UserDefaults.standard.removeObject(forKey: Self.debugProOverrideKey)
        logger.debugOverrideChanged(nil)
        Task { await updateSubscriptionStatus(source: "debug_override_cleared") }
    }

    func refreshStoreKitStatus() {
        Task { await updateSubscriptionStatus(source: "debug_manual_refresh") }
    }

    func setDebugSimulateNextPurchasePending(_ value: Bool) {
        simulateNextPurchasePending = value
    }

    func setDebugSimulateNextRestoreOutcome(_ outcome: StoreRestoreOutcome?) {
        simulateNextRestoreOutcome = outcome
    }

    func dumpStoreKitEntitlements() async {
        isDumpingStoreKitEntitlements = true
        defer { isDumpingStoreKitEntitlements = false }

        var totalCount = 0
        var proGrantingCount = 0
        var unverifiedCount = 0
        var lines = [
            "=== StoreKit currentEntitlements dump ===",
            "Debug override: \(debugProOverride.map { $0 ? "Forcing Pro" : "Forcing Free" } ?? "StoreKit")",
            "Effective isProUser before dump: \(isProUser)"
        ]

        for await result in Transaction.currentEntitlements {
            totalCount += 1

            switch result {
            case .verified(let transaction):
                let grantsPro = grantsProAccess(transaction)
                if grantsPro {
                    proGrantingCount += 1
                }

                lines.append([
                    "Verified entitlement",
                    "productID=\(transaction.productID)",
                    "revocationDate=\(Self.debugDateDescription(transaction.revocationDate))",
                    "expirationDate=\(Self.debugDateDescription(transaction.expirationDate))",
                    "grantsPro=\(grantsPro)"
                ].joined(separator: " | "))

            case .unverified(let transaction, let error):
                unverifiedCount += 1
                lines.append([
                    "Unverified entitlement",
                    "productID=\(transaction.productID)",
                    "revocationDate=\(Self.debugDateDescription(transaction.revocationDate))",
                    "expirationDate=\(Self.debugDateDescription(transaction.expirationDate))",
                    "error=\(error)"
                ].joined(separator: " | "))
            }
        }

        let summary = Self.debugEntitlementDiagnosticSummary(
            totalCount: totalCount,
            proGrantingCount: proGrantingCount,
            unverifiedCount: unverifiedCount
        )
        storeKitEntitlementDiagnosticSummary = summary
        lines.append("Summary: \(summary)")
        lines.append("=== End StoreKit currentEntitlements dump ===")
        logger.debugEntitlementsDumped(
            entitlementCount: totalCount,
            proEntitlementCount: proGrantingCount,
            unverifiedCount: unverifiedCount
        )
        print(lines.joined(separator: "\n"))
    }

    private static func debugDateDescription(_ date: Date?) -> String {
        guard let date else { return "nil" }
        return ISO8601DateFormatter().string(from: date)
    }
    #endif

    // MARK: - Transactions Stream
    private func startTransactionListener() {
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }

                switch result {
                case .verified(let transaction):
                    self.logger.transactionUpdateReceived(productID: transaction.productID)
                    await self.updateSubscriptionStatus(source: "transaction_update")
                    await transaction.finish()
                    self.logger.transactionUpdateCompleted(productID: transaction.productID)

                case .unverified(let transaction, let error):
                    self.logger.transactionUpdateFailed(productID: transaction.productID, error: error)
                }
            }
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification
        case purchaseDidNotUnlockPro

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "Transaction verification failed."
            case .purchaseDidNotUnlockPro:
                return "Purchase completed, but Pro access was not found. Please try restoring purchases."
            }
        }
    }
}

enum StorePurchaseOutcome: Equatable {
    case purchased
    case pending
    case cancelled
}

enum StoreRestoreOutcome: Equatable {
    case restored
    case notFound
}

struct ProEntitlementSnapshot: Equatable {
    let productID: String
    let revocationDate: Date?
    let expirationDate: Date?
}
