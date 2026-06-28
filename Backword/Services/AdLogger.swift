import Foundation
import GoogleMobileAds
import OSLog

struct AdLogger {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Backword",
        category: "ads"
    )   
    private let analytics = BackwordAnalyticsService.shared

    func interstitialAdLoaded() {
        logger.info("Interstitial ad loaded in \(appEnvironment, privacy: .public)")
        logAnalytics(.loaded, format: .interstitial)
    }

    func interstitialAdFailedToLoad(_ error: Error) {
        logger.error("Interstitial ad failed to load: \(describe(error), privacy: .public)")
        logAnalytics(.loadFailed, format: .interstitial, error: error)
    }

    func interstitialSkippedDebugDisabled() {
        logger.info("Interstitial skipped in \(appEnvironment, privacy: .public) because debug ads are disabled")
        logAnalytics(.skipped, format: .interstitial, result: "debug_ads_disabled")
    }

    func interstitialUnavailableForDirectPresentation() {
        logger.info("Interstitial unavailable for direct presentation in \(appEnvironment, privacy: .public)")
        logAnalytics(.unavailable, format: .interstitial, result: "direct_presentation")
    }

    func interstitialDirectPresentationPresenterUnavailable() {
        logger.info("Interstitial direct presentation skipped in \(appEnvironment, privacy: .public) because no presenter was available")
        logAnalytics(.presenterUnavailable, format: .interstitial, result: "direct_presentation")
    }

    func interstitialDirectPresentationRequested(attemptID: String) {
        logger.info("Interstitial direct presentation requested in \(appEnvironment, privacy: .public)")
        logAnalytics(.presentationRequested, format: .interstitial, attemptID: attemptID, result: "direct_presentation")
    }

    func interstitialSkippedDebugDisabled(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial skipped for \(placement.rawValue, privacy: .public) in \(appEnvironment, privacy: .public) because debug ads are disabled")
        logAnalytics(.skipped, format: .interstitial, placement: placement, result: "debug_ads_disabled")
    }

    func interstitialAlreadyShownToday(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial skipped for \(placement.rawValue, privacy: .public) in \(appEnvironment, privacy: .public) because it has already shown today")
        logAnalytics(.skipped, format: .interstitial, placement: placement, result: "already_shown_today")
    }

    func interstitialUnavailableAttemptingForegroundLoad(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial unavailable for \(placement.rawValue, privacy: .public) in \(appEnvironment, privacy: .public); attempting foreground load")
        logAnalytics(.foregroundLoadStarted, format: .interstitial, placement: placement)
    }

    func interstitialAlreadyShownAfterForegroundLoadRequest(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial skipped for \(placement.rawValue, privacy: .public) after foreground load request because it has already shown today")
        logAnalytics(.skipped, format: .interstitial, placement: placement, result: "already_shown_after_foreground_load")
    }

    func interstitialForegroundLoadFailed(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial foreground load failed for \(placement.rawValue, privacy: .public); continuing without ad")
        logAnalytics(.foregroundLoadFailed, format: .interstitial, placement: placement)
    }

    func interstitialStillUnavailableAfterForegroundLoad(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial still unavailable after foreground load for \(placement.rawValue, privacy: .public); continuing without ad")
        logAnalytics(.unavailable, format: .interstitial, placement: placement, result: "after_foreground_load")
    }

    func interstitialRequestIgnoredAlreadyInProgress(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial request ignored for \(placement.rawValue, privacy: .public) because another interstitial is in progress")
        logAnalytics(.skipped, format: .interstitial, placement: placement, result: "already_in_progress")
    }

    func interstitialPresenterUnavailable(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial presenter unavailable for \(placement.rawValue, privacy: .public) in \(appEnvironment, privacy: .public); continuing without ad")
        logAnalytics(.presenterUnavailable, format: .interstitial, placement: placement)
    }

    func interstitialPresentationRequested(for placement: AdService.UserDefaultsKey, attemptID: String) {
        logger.info("Interstitial presentation requested for \(placement.rawValue, privacy: .public) in \(appEnvironment, privacy: .public) with attempt \(attemptID, privacy: .public)")
        logAnalytics(.presentationRequested, format: .interstitial, placement: placement, attemptID: attemptID)
    }

    func interstitialAdFailedToPresent(_ error: Error, attemptID: String?, presentedAt: Date?) {
        logger.error("Interstitial ad failed to present: \(describe(error), privacy: .public)")
        logAnalytics(
            .failedToPresent,
            format: .interstitial,
            attemptID: attemptID,
            presentedAt: presentedAt,
            secondsSincePresent: secondsSince(presentedAt),
            error: error
        )
    }

    func interstitialAdDidDismiss(attemptID: String?, presentedAt: Date?) {
        logger.info("Interstitial ad did dismiss")
        logAnalytics(
            .didDismiss,
            format: .interstitial,
            attemptID: attemptID,
            presentedAt: presentedAt,
            secondsSincePresent: secondsSince(presentedAt)
        )
    }

    func rewardedAdLoaded() {
        logger.info("Rewarded ad loaded in \(appEnvironment, privacy: .public)")
        logAnalytics(.loaded, format: .rewarded)
    }

    func rewardedAdFailedToLoad(_ error: Error) {
        logger.error("Rewarded ad failed to load: \(describe(error), privacy: .public)")
        logAnalytics(.loadFailed, format: .rewarded, error: error)
    }

    func rewardedAdRequestIgnoredAlreadyInProgress() {
        logger.info("Rewarded ad request ignored in \(appEnvironment, privacy: .public) because another rewarded ad is in progress")
        logAnalytics(.skipped, format: .rewarded, result: "already_in_progress")
    }

    func rewardedAdSkippedDebugDisabled() {
        logger.info("Rewarded ad skipped in \(appEnvironment, privacy: .public) because debug ads are disabled")
        logAnalytics(.skipped, format: .rewarded, result: "debug_ads_disabled")
    }

    func rewardedAdUnavailableGrantingFallback() {
        logger.info("Rewarded ad unavailable in \(appEnvironment, privacy: .public); granting fallback result")
        logAnalytics(.unavailable, format: .rewarded, result: "granting_fallback")
    }

    func rewardedAdPresenterUnavailable() {
        logger.info("Rewarded ad presenter unavailable in \(appEnvironment, privacy: .public)")
        logAnalytics(.presenterUnavailable, format: .rewarded)
    }

    func rewardedAdPresentationRequested(attemptID: String) {
        logger.info("Rewarded ad presentation requested in \(appEnvironment, privacy: .public) with attempt \(attemptID, privacy: .public)")
        logAnalytics(.presentationRequested, format: .rewarded, attemptID: attemptID)
    }

    func rewardedAdRewardEarned(attemptID: String?) {
        logger.info("Rewarded ad reward earned")
        logAnalytics(.rewardEarned, format: .rewarded, attemptID: attemptID)
    }

    func rewardedAdCompleted(with result: AdService.RewardedAdResult, attemptID: String?, presentedAt: Date?) {
        logger.info("Rewarded ad completed with result \(String(describing: result), privacy: .public)")
        logAnalytics(
            .completed,
            format: .rewarded,
            attemptID: attemptID,
            result: String(describing: result),
            presentedAt: presentedAt,
            secondsSincePresent: secondsSince(presentedAt)
        )
    }

    func rewardedAdFailedToPresent(_ error: Error, attemptID: String?, presentedAt: Date?) {
        logger.error("Rewarded ad failed to present: \(describe(error), privacy: .public)")
        logAnalytics(
            .failedToPresent,
            format: .rewarded,
            attemptID: attemptID,
            presentedAt: presentedAt,
            secondsSincePresent: secondsSince(presentedAt),
            error: error
        )
    }

    func rewardedAdDidDismiss(attemptID: String?, presentedAt: Date?) {
        logger.info("Rewarded ad did dismiss")
        logAnalytics(
            .didDismiss,
            format: .rewarded,
            attemptID: attemptID,
            presentedAt: presentedAt,
            secondsSincePresent: secondsSince(presentedAt)
        )
    }

    func fullScreenAdWillPresent(_ ad: FullScreenPresentingAd, attemptID: String?, presentedAt: Date) {
        logger.info("\(format(for: ad), privacy: .public) ad will present")
        logAnalytics(.willPresent, format: analyticsFormat(for: ad), attemptID: attemptID, presentedAt: presentedAt)
    }

    func fullScreenAdWillDismiss(_ ad: FullScreenPresentingAd, attemptID: String?, presentedAt: Date?) {
        logger.info("\(format(for: ad), privacy: .public) ad will dismiss")
        logAnalytics(
            .willDismiss,
            format: analyticsFormat(for: ad),
            attemptID: attemptID,
            presentedAt: presentedAt,
            secondsSincePresent: secondsSince(presentedAt)
        )
    }

    func possibleStuckAd(format: BackwordAnalyticsEvent.AdFormat, placement: AdService.UserDefaultsKey?, attemptID: String, presentedAt: Date) {
        logger.error("\(format.rawValue, privacy: .public) ad possible stuck after 45 seconds for attempt \(attemptID, privacy: .public)")
        logAnalytics(
            .possibleStuck,
            format: format,
            placement: placement,
            attemptID: attemptID,
            result: "no_dismiss_callback_after_45_seconds",
            presentedAt: presentedAt,
            secondsSincePresent: secondsSince(presentedAt)
        )
    }

    func recoveringPossiblyStuckAd(format: BackwordAnalyticsEvent.AdFormat, attemptID: String) {
        logger.error("Recovering possibly stuck \(format.rawValue, privacy: .public) ad for attempt \(attemptID, privacy: .public)")
    }

    private var appEnvironment: String {
        #if DEBUG
        return "debug"
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "testflight"
        }
        return "appstore"
        #endif
    }

    private func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
    }

    private func secondsSince(_ date: Date?) -> TimeInterval? {
        guard let date else { return nil }
        return Date().timeIntervalSince(date)
    }

    private func format(for ad: FullScreenPresentingAd) -> String {
        if ad is InterstitialAd {
            return "Interstitial"
        } else if ad is RewardedAd {
            return "Rewarded"
        } else {
            return "Unknown full-screen"
        }
    }

    private func analyticsFormat(for ad: FullScreenPresentingAd) -> BackwordAnalyticsEvent.AdFormat {
        if ad is InterstitialAd {
            return .interstitial
        } else if ad is RewardedAd {
            return .rewarded
        } else {
            return .unknown
        }
    }

    private func logAnalytics(
        _ action: BackwordAnalyticsEvent.AdAction,
        format: BackwordAnalyticsEvent.AdFormat,
        placement: AdService.UserDefaultsKey? = nil,
        attemptID: String? = nil,
        result: String? = nil,
        presentedAt: Date? = nil,
        secondsSincePresent: TimeInterval? = nil,
        error: Error? = nil
    ) {
        analytics.log(.adLifecycle(
            action: action,
            format: format,
            placement: placement,
            attemptID: attemptID,
            result: result,
            presentedAt: presentedAt,
            secondsSincePresent: secondsSincePresent,
            error: error,
            environment: appEnvironment
        ))
    }
}
