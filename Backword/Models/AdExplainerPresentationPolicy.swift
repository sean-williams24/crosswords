import Foundation

enum AdExplainerPresentationPolicy {
    static func shouldShow(
        isProUser: Bool,
        hasDismissedExplainer: Bool,
        isInterstitialEligibleToday: Bool
    ) -> Bool {
        !isProUser
            && !hasDismissedExplainer
            && isInterstitialEligibleToday
    }
}
