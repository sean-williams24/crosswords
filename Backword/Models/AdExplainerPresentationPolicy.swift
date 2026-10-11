import Foundation

enum AdExplainerPresentationPolicy {
    static func shouldShow(
        isProUser: Bool,
        hasDismissedExplainer: Bool,
        isInterstitialEligibleToday: Bool,
        preGameInterstitialsEnabled: Bool = AdConfiguration.preGameInterstitialsEnabled
    ) -> Bool {
        preGameInterstitialsEnabled
            && !isProUser
            && !hasDismissedExplainer
            && isInterstitialEligibleToday
    }

    static func shouldOfferExplanationSetting(preGameInterstitialsEnabled: Bool) -> Bool {
        preGameInterstitialsEnabled
    }
}
