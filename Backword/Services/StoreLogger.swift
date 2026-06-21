import Foundation
import OSLog

struct StoreLogger {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Backword",
        category: "store"
    )
    private let analytics = BackwordAnalyticsService.shared

    func productsLoadRequested(productIDs: [String]) {
        logger.info("Store products load requested for \(productIDs.joined(separator: ","), privacy: .public) in \(AppEnvironment.current, privacy: .public)")
        logAnalytics(.productsLoadRequested, result: productIDs.joined(separator: ","))
    }

    func productsLoaded(_ products: [ProductSnapshot], requestedProductIDs: [String]) {
        let productIDs = products.map(\.id)
        let missingProductIDs = requestedProductIDs.filter { !productIDs.contains($0) }
        logger.info("Store products loaded: count=\(products.count, privacy: .public), missing=\(missingProductIDs.joined(separator: ","), privacy: .public)")
        logAnalytics(
            .productsLoaded,
            productCount: products.count,
            missingProductIDs: missingProductIDs
        )
    }

    func productsLoadFailed(_ error: Error) {
        logger.error("Store products failed to load: \(describe(error), privacy: .public)")
        logAnalytics(.productsLoadFailed, error: error)
    }

    func purchaseRequested(productID: String) {
        logger.info("Store purchase requested for \(productID, privacy: .public) in \(AppEnvironment.current, privacy: .public)")
        logAnalytics(.purchaseRequested, productID: productID)
    }

    func purchaseCompleted(productID: String, result: StorePurchaseOutcome) {
        logger.info("Store purchase completed for \(productID, privacy: .public) with result \(String(describing: result), privacy: .public)")
        logAnalytics(.purchaseCompleted, productID: productID, result: String(describing: result))
    }

    func purchaseFailed(productID: String, error: Error) {
        logger.error("Store purchase failed for \(productID, privacy: .public): \(describe(error), privacy: .public)")
        logAnalytics(.purchaseFailed, productID: productID, error: error)
    }

    func purchaseDidNotUnlockPro(productID: String) {
        logger.error("Store purchase completed for \(productID, privacy: .public) but did not unlock Pro")
        logAnalytics(.purchaseFailed, productID: productID, result: "did_not_unlock_pro")
    }

    func restoreRequested(source: String) {
        logger.info("Store restore requested from \(source, privacy: .public) in \(AppEnvironment.current, privacy: .public)")
        logAnalytics(.restoreRequested, result: source)
    }

    func restoreCompleted(_ outcome: StoreRestoreOutcome, source: String) {
        logger.info("Store restore completed from \(source, privacy: .public) with result \(String(describing: outcome), privacy: .public)")
        logAnalytics(.restoreCompleted, result: "\(source):\(String(describing: outcome))")
    }

    func restoreFailed(source: String, error: Error) {
        logger.error("Store restore failed from \(source, privacy: .public): \(describe(error), privacy: .public)")
        logAnalytics(.restoreFailed, result: source, error: error)
    }

    func subscriptionStatusRefreshStarted(source: String) {
        logger.info("Store subscription status refresh started from \(source, privacy: .public)")
        logAnalytics(.subscriptionStatusRefreshStarted, result: source)
    }

    func subscriptionStatusRefreshCompleted(
        source: String,
        entitlementCount: Int,
        proEntitlementCount: Int,
        unverifiedCount: Int,
        isProUser: Bool
    ) {
        logger.info("Store subscription status refresh completed from \(source, privacy: .public): isProUser=\(isProUser, privacy: .public), entitlements=\(entitlementCount, privacy: .public), proEntitlements=\(proEntitlementCount, privacy: .public), unverified=\(unverifiedCount, privacy: .public)")
        logAnalytics(
            .subscriptionStatusRefreshCompleted,
            result: isProUser ? "pro" : "free",
            entitlementCount: entitlementCount,
            proEntitlementCount: proEntitlementCount,
            unverifiedCount: unverifiedCount
        )
    }

    func transactionUpdateReceived(productID: String) {
        logger.info("Store transaction update received for \(productID, privacy: .public)")
        logAnalytics(.transactionUpdateReceived, productID: productID)
    }

    func transactionUpdateCompleted(productID: String) {
        logger.info("Store transaction update completed for \(productID, privacy: .public)")
        logAnalytics(.transactionUpdateCompleted, productID: productID)
    }

    func transactionUpdateFailed(productID: String?, error: Error) {
        logger.error("Store transaction update failed for \(productID ?? "unknown", privacy: .public): \(describe(error), privacy: .public)")
        logAnalytics(.transactionUpdateFailed, productID: productID, error: error)
    }

    #if DEBUG
    func debugOverrideChanged(_ value: Bool?) {
        let result = value.map { $0 ? "force_pro" : "force_free" } ?? "cleared"
        logger.info("Store debug Pro override changed to \(result, privacy: .public)")
        logAnalytics(.debugOverrideChanged, result: result)
    }

    func debugEntitlementsDumped(
        entitlementCount: Int,
        proEntitlementCount: Int,
        unverifiedCount: Int
    ) {
        logger.info("Store debug entitlements dumped: entitlements=\(entitlementCount, privacy: .public), proEntitlements=\(proEntitlementCount, privacy: .public), unverified=\(unverifiedCount, privacy: .public)")
        logAnalytics(
            .debugEntitlementsDumped,
            entitlementCount: entitlementCount,
            proEntitlementCount: proEntitlementCount,
            unverifiedCount: unverifiedCount
        )
    }
    #endif

    private func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
    }

    private func logAnalytics(
        _ action: BackwordAnalyticsEvent.StoreAction,
        productID: String? = nil,
        result: String? = nil,
        productCount: Int? = nil,
        entitlementCount: Int? = nil,
        proEntitlementCount: Int? = nil,
        unverifiedCount: Int? = nil,
        missingProductIDs: [String] = [],
        error: Error? = nil
    ) {
        analytics.log(.storeLifecycle(
            action: action,
            productID: productID,
            result: result,
            productCount: productCount,
            entitlementCount: entitlementCount,
            proEntitlementCount: proEntitlementCount,
            unverifiedCount: unverifiedCount,
            missingProductIDs: missingProductIDs,
            error: error,
            environment: AppEnvironment.current
        ))
    }

    struct ProductSnapshot {
        let id: String
    }
}
