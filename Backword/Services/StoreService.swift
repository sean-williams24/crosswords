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

        // FIX: Combine initial loads into a single Task structured concurrency block
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
    func purchase(_ product: Product) async throws {
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            // Always finish the transaction AFTER updating status successfully
            await transaction.finish()

        case .userCancelled, .pending:
            break

        @unknown default:
            break
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Subscription Status
    func updateSubscriptionStatus() async {
        // FIX: Respect the debug override if active
//        #if DEBUG
//        if let debugProOverride {
//            isProUser = debugProOverride
//            return
//        }
//        #endif

        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.monthlyID || transaction.productID == Self.annualID,
               transaction.revocationDate == nil {
                hasActiveSubscription = true
            }
        }

        isProUser = hasActiveSubscription
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

    // MARK: - Debug
    #if DEBUG
    private static let debugProOverrideKey = "debug_isProUser"
    private var debugProOverride: Bool?

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

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "Transaction verification failed."
            }
        }
    }
}
