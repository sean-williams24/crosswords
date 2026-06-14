import StoreKit

@MainActor
final class StoreService: ObservableObject {

    // MARK: - Product IDs
    static let monthlyID = "com.backword.monthlypro"
    static let annualID = "com.backword.annualpro"

    // MARK: - Published State
    @Published private(set) var products: [Product] = []
    @Published private(set) var isProUser = false
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

    // MARK: - Init
    init() {
        startTransactionListener()

        #if DEBUG
        if let override = UserDefaults.standard.object(forKey: Self.debugProOverrideKey) as? Bool {
            debugProOverride = override
            isProUser = override
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
        do {
            products = try await Product.products(for: [Self.monthlyID, Self.annualID])
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async throws -> StorePurchaseOutcome {
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        #if DEBUG
        if let simulatedOutcome = Self.debugSimulatedPurchaseOutcome(
            simulateNextPurchasePending: simulateNextPurchasePending
        ) {
            simulateNextPurchasePending = false
            return simulatedOutcome
        }
        #endif

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            if grantsProAccess(transaction) {
                isProUser = true
            } else {
                await updateSubscriptionStatus()
            }
            await transaction.finish()
            guard isProUser else {
                throw StoreError.purchaseDidNotUnlockPro
            }
            return .purchased

        case .userCancelled:
            return .cancelled

        case .pending:
            return .pending

        @unknown default:
            return .pending
        }
    }

    // MARK: - Restore
    func restorePurchases() async throws -> StoreRestoreOutcome {
        #if DEBUG
        if let simulatedOutcome = simulateNextRestoreOutcome {
            simulateNextRestoreOutcome = nil
            if simulatedOutcome == .restored {
                isProUser = true
            }
            return simulatedOutcome
        }

        if debugProOverride != nil {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            return isProUser ? .restored : .notFound
        }
        #endif

        if await refreshProStatusFromCurrentEntitlements() {
            return .restored
        }

        try await AppStore.sync()
        return await refreshProStatusFromCurrentEntitlements() ? .restored : .notFound
    }

    // MARK: - Subscription Status
    func updateSubscriptionStatus() async {
        #if DEBUG
        if let debugProOverride {
            isProUser = debugProOverride
            return
        }
        #endif

        await refreshProStatusFromCurrentEntitlements()
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
    private func refreshProStatusFromCurrentEntitlements() async -> Bool {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               grantsProAccess(transaction) {
                hasActiveSubscription = true
            }
        }

        isProUser = hasActiveSubscription
        return hasActiveSubscription
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
    }

    func clearDebugProOverride() {
        debugProOverride = nil
        UserDefaults.standard.removeObject(forKey: Self.debugProOverrideKey)
        Task { await updateSubscriptionStatus() }
    }

    func refreshStoreKitStatus() {
        Task { await updateSubscriptionStatus() }
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

                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Received unverified transaction update: \(error)")
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
