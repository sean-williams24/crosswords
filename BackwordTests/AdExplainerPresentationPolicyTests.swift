import Testing
@testable import Backword

@Suite("Ad explainer presentation policy")
struct AdExplainerPresentationPolicyTests {
    @Test("Non-Pro user with eligible ad slot and no dismissal sees explainer")
    func eligibleFreeUserSeesExplainer() {
        #expect(AdExplainerPresentationPolicy.shouldShow(
            isProUser: false,
            hasDismissedExplainer: false,
            isInterstitialEligibleToday: true
        ))
    }

    @Test("Pro users never see explainer")
    func proUserDoesNotSeeExplainer() {
        #expect(!AdExplainerPresentationPolicy.shouldShow(
            isProUser: true,
            hasDismissedExplainer: false,
            isInterstitialEligibleToday: true
        ))
    }

    @Test("Dismissed explainer preference skips explainer")
    func dismissedPreferenceSkipsExplainer() {
        #expect(!AdExplainerPresentationPolicy.shouldShow(
            isProUser: false,
            hasDismissedExplainer: true,
            isInterstitialEligibleToday: true
        ))
    }

    @Test("Same-day already shown ad slot skips explainer")
    func ineligibleAdSlotSkipsExplainer() {
        #expect(!AdExplainerPresentationPolicy.shouldShow(
            isProUser: false,
            hasDismissedExplainer: false,
            isInterstitialEligibleToday: false
        ))
    }
}
