import Foundation
import FirebaseAnalytics
import FirebaseCore
import OSLog

struct BackwordAnalyticsEvent: Equatable {
    static let adLifecycleName = "bw_ad_lifecycle"
    static let storeLifecycleName = "bw_store_lifecycle"

    let name: String
    let parameters: [String: String]

    static func adLifecycle(
        action: AdAction,
        format: AdFormat,
        placement: AdService.UserDefaultsKey? = nil,
        attemptID: String? = nil,
        result: String? = nil,
        presentedAt: Date? = nil,
        secondsSincePresent: TimeInterval? = nil,
        error: Error? = nil,
        environment: String = AppEnvironment.current
    ) -> BackwordAnalyticsEvent {
        var parameters = [
            "action": action.rawValue,
            "ad_format": format.rawValue,
            "environment": environment
        ]

        if let placement {
            parameters["placement"] = placement.rawValue
        }

        if let attemptID {
            parameters["ad_attempt_id"] = attemptID
        }

        if let result {
            parameters["result"] = result
        }

        if let presentedAt {
            parameters["presented_at"] = ISO8601DateFormatter().string(from: presentedAt)
        }

        if let secondsSincePresent {
            parameters["seconds_since_present"] = String(format: "%.1f", secondsSincePresent)
        }

        if let error {
            let nsError = error as NSError
            parameters["error_domain"] = nsError.domain
            parameters["error_code"] = String(nsError.code)
        }

        return BackwordAnalyticsEvent(name: adLifecycleName, parameters: parameters)
    }

    static func storeLifecycle(
        action: StoreAction,
        productID: String? = nil,
        result: String? = nil,
        productCount: Int? = nil,
        entitlementCount: Int? = nil,
        proEntitlementCount: Int? = nil,
        unverifiedCount: Int? = nil,
        missingProductIDs: [String] = [],
        error: Error? = nil,
        environment: String = AppEnvironment.current
    ) -> BackwordAnalyticsEvent {
        var parameters = [
            "action": action.rawValue,
            "environment": environment
        ]

        if let productID {
            parameters["product_id"] = productID
        }

        if let result {
            parameters["result"] = result
        }

        if let productCount {
            parameters["product_count"] = String(productCount)
        }

        if let entitlementCount {
            parameters["entitlement_count"] = String(entitlementCount)
        }

        if let proEntitlementCount {
            parameters["pro_entitlement_count"] = String(proEntitlementCount)
        }

        if let unverifiedCount {
            parameters["unverified_count"] = String(unverifiedCount)
        }

        if !missingProductIDs.isEmpty {
            parameters["missing_product_ids"] = missingProductIDs.joined(separator: ",")
        }

        if let error {
            let nsError = error as NSError
            parameters["error_domain"] = nsError.domain
            parameters["error_code"] = String(nsError.code)
        }

        return BackwordAnalyticsEvent(name: storeLifecycleName, parameters: parameters)
    }

    enum AdAction: String {
        case loaded
        case loadFailed = "load_failed"
        case skipped
        case unavailable
        case foregroundLoadStarted = "foreground_load_started"
        case foregroundLoadFailed = "foreground_load_failed"
        case presenterUnavailable = "presenter_unavailable"
        case presentationRequested = "presentation_requested"
        case failedToPresent = "failed_to_present"
        case willPresent = "will_present"
        case willDismiss = "will_dismiss"
        case didDismiss = "did_dismiss"
        case possibleStuck = "possible_stuck"
        case rewardEarned = "reward_earned"
        case completed
    }

    enum AdFormat: String {
        case interstitial
        case rewarded
        case unknown
    }

    enum StoreAction: String {
        case productsLoadRequested = "products_load_requested"
        case productsLoaded = "products_loaded"
        case productsLoadFailed = "products_load_failed"
        case purchaseRequested = "purchase_requested"
        case purchaseCompleted = "purchase_completed"
        case purchaseFailed = "purchase_failed"
        case restoreRequested = "restore_requested"
        case restoreCompleted = "restore_completed"
        case restoreFailed = "restore_failed"
        case subscriptionStatusRefreshStarted = "subscription_status_refresh_started"
        case subscriptionStatusRefreshCompleted = "subscription_status_refresh_completed"
        case transactionUpdateReceived = "transaction_update_received"
        case transactionUpdateCompleted = "transaction_update_completed"
        case transactionUpdateFailed = "transaction_update_failed"
        case debugOverrideChanged = "debug_override_changed"
        case debugEntitlementsDumped = "debug_entitlements_dumped"
    }
}

final class BackwordAnalyticsService {
    static let shared = BackwordAnalyticsService()

    private var isConfigured = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Backword",
        category: "analytics"
    )

    private init() {}

    @discardableResult
    func configureIfPossible() -> Bool {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            logger.info("Firebase Analytics not configured because GoogleService-Info.plist is missing")
            return false
        }

        if FirebaseApp.app() != nil {
            isConfigured = true
            return true
        }

        FirebaseApp.configure()
        let didConfigure = FirebaseApp.app() != nil
        if didConfigure {
            isConfigured = true
            logger.info("Firebase Analytics configured")
        } else {
            logger.error("Firebase Analytics configuration did not create a Firebase app")
        }
        return didConfigure
    }

    func log(_ event: BackwordAnalyticsEvent) {
        guard isConfigured else { return }
        Analytics.logEvent(event.name, parameters: event.parameters)
    }
}

enum AppEnvironment {
    static var current: String {
        #if DEBUG
        return "debug"
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }
        return "appstore"
        #endif
    }
}
