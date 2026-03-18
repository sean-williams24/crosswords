import StoreKit

@MainActor
final class StoreService: ObservableObject {

    // MARK: - Product IDs

    static let monthlyID = "com.crosswords.pro.monthly"
    static let annualID = "com.crosswords.pro.annual"

    // MARK: - Published State

    @Published private(set) var products: [Product] = []
    @Published private(set) var isProUser = false
    @Published private(set) var purchaseInProgress = false

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var annualProduct: Product? { products.first { $0.id == Self.annualID } }

    private var transactionListener: Task<Void, Never>?

    // MARK: - Init

    init() {
        transactionListener = listenForTransactions()
        #if DEBUG
        if let override = UserDefaults.standard.object(forKey: Self.debugProOverrideKey) as? Bool {
            debugProOverride = override
            isProUser = override
        }
        #endif
        Task { await loadProducts() }
        Task { await updateSubscriptionStatus() }
    }

    deinit {
        transactionListener?.cancel()
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
            await transaction.finish()
            await updateSubscriptionStatus()

        case .userCancelled:
            break

        case .pending:
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
        #if DEBUG
        if debugProOverride != nil { return }
        #endif
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.monthlyID || transaction.productID == Self.annualID {
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
    }
    #endif

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await transaction.finish()
                    await self?.updateSubscriptionStatus()
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
