import Foundation
import GoogleMobileAds
import OSLog

struct AdLogger {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Backword",
        category: "ads"
    )

    func interstitialAdLoaded() {
        logger.info("Interstitial ad loaded in \(appEnvironment, privacy: .public)")
    }

    func interstitialAdFailedToLoad(_ error: Error) {
        logger.error("Interstitial ad failed to load: \(describe(error), privacy: .public)")
    }

    func interstitialSkippedDebugDisabled() {
        logger.info("Interstitial skipped in \(appEnvironment, privacy: .public) because debug ads are disabled")
    }

    func interstitialUnavailableForDirectPresentation() {
        logger.info("Interstitial unavailable for direct presentation in \(appEnvironment, privacy: .public)")
    }

    func interstitialDirectPresentationPresenterUnavailable() {
        logger.info("Interstitial direct presentation skipped in \(appEnvironment, privacy: .public) because no presenter was available")
    }

    func interstitialDirectPresentationRequested() {
        logger.info("Interstitial direct presentation requested in \(appEnvironment, privacy: .public)")
    }

    func interstitialSkippedDebugDisabled(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial skipped for \(placement.rawValue, privacy: .public) in \(appEnvironment, privacy: .public) because debug ads are disabled")
    }

    func interstitialAlreadyShownToday(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial skipped for \(placement.rawValue, privacy: .public) in \(appEnvironment, privacy: .public) because it has already shown today")
    }

    func interstitialUnavailableAttemptingForegroundLoad(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial unavailable for \(placement.rawValue, privacy: .public) in \(appEnvironment, privacy: .public); attempting foreground load")
    }

    func interstitialAlreadyShownAfterForegroundLoadRequest(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial skipped for \(placement.rawValue, privacy: .public) after foreground load request because it has already shown today")
    }

    func interstitialForegroundLoadFailed(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial foreground load failed for \(placement.rawValue, privacy: .public); continuing without ad")
    }

    func interstitialStillUnavailableAfterForegroundLoad(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial still unavailable after foreground load for \(placement.rawValue, privacy: .public); continuing without ad")
    }

    func interstitialRequestIgnoredAlreadyInProgress(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial request ignored for \(placement.rawValue, privacy: .public) because another interstitial is in progress")
    }

    func interstitialPresenterUnavailable(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial presenter unavailable for \(placement.rawValue, privacy: .public) in \(appEnvironment, privacy: .public); continuing without ad")
    }

    func interstitialPresentationRequested(for placement: AdService.UserDefaultsKey) {
        logger.info("Interstitial presentation requested for \(placement.rawValue, privacy: .public) in \(appEnvironment, privacy: .public)")
    }

    func interstitialAdFailedToPresent(_ error: Error) {
        logger.error("Interstitial ad failed to present: \(describe(error), privacy: .public)")
    }

    func interstitialAdDidDismiss() {
        logger.info("Interstitial ad did dismiss")
    }

    func rewardedAdLoaded() {
        logger.info("Rewarded ad loaded in \(appEnvironment, privacy: .public)")
    }

    func rewardedAdFailedToLoad(_ error: Error) {
        logger.error("Rewarded ad failed to load: \(describe(error), privacy: .public)")
    }

    func rewardedAdRequestIgnoredAlreadyInProgress() {
        logger.info("Rewarded ad request ignored in \(appEnvironment, privacy: .public) because another rewarded ad is in progress")
    }

    func rewardedAdSkippedDebugDisabled() {
        logger.info("Rewarded ad skipped in \(appEnvironment, privacy: .public) because debug ads are disabled")
    }

    func rewardedAdUnavailableGrantingFallback() {
        logger.info("Rewarded ad unavailable in \(appEnvironment, privacy: .public); granting fallback result")
    }

    func rewardedAdPresenterUnavailable() {
        logger.info("Rewarded ad presenter unavailable in \(appEnvironment, privacy: .public)")
    }

    func rewardedAdPresentationRequested() {
        logger.info("Rewarded ad presentation requested in \(appEnvironment, privacy: .public)")
    }

    func rewardedAdRewardEarned() {
        logger.info("Rewarded ad reward earned")
    }

    func rewardedAdCompleted(with result: AdService.RewardedAdResult) {
        logger.info("Rewarded ad completed with result \(String(describing: result), privacy: .public)")
    }

    func rewardedAdFailedToPresent(_ error: Error) {
        logger.error("Rewarded ad failed to present: \(describe(error), privacy: .public)")
    }

    func rewardedAdDidDismiss() {
        logger.info("Rewarded ad did dismiss")
    }

    func fullScreenAdWillPresent(_ ad: FullScreenPresentingAd) {
        logger.info("\(format(for: ad), privacy: .public) ad will present")
    }

    func fullScreenAdWillDismiss(_ ad: FullScreenPresentingAd) {
        logger.info("\(format(for: ad), privacy: .public) ad will dismiss")
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

    private func format(for ad: FullScreenPresentingAd) -> String {
        if ad is InterstitialAd {
            return "Interstitial"
        } else if ad is RewardedAd {
            return "Rewarded"
        } else {
            return "Unknown full-screen"
        }
    }
}
