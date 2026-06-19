import Foundation
import FirebaseAnalytics
import FirebaseCore
import OSLog

struct BackwordAnalyticsEvent: Equatable {
    static let adLifecycleName = "bw_ad_lifecycle"

    let name: String
    let parameters: [String: String]

    static func adLifecycle(
        action: AdAction,
        format: AdFormat,
        placement: AdService.UserDefaultsKey? = nil,
        result: String? = nil,
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

        if let result {
            parameters["result"] = result
        }

        if let error {
            let nsError = error as NSError
            parameters["error_domain"] = nsError.domain
            parameters["error_code"] = String(nsError.code)
        }

        return BackwordAnalyticsEvent(name: adLifecycleName, parameters: parameters)
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
        case rewardEarned = "reward_earned"
        case completed
    }

    enum AdFormat: String {
        case interstitial
        case rewarded
        case unknown
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
