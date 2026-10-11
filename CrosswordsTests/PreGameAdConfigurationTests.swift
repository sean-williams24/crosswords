import Testing
@testable import Backword

@Suite("Pre-game ad configuration")
struct PreGameAdConfigurationTests {
    @Test("Pre-game ads are disabled by default")
    func disabledByDefault() {
        #expect(!AdConfiguration.preGameInterstitialsEnabled)
    }

    @Test("Paused ads suppress the explainer regardless of opt-out", arguments: [false, true])
    func pausedAdsSuppressExplainer(hasDismissedExplainer: Bool) {
        #expect(!AdExplainerPresentationPolicy.shouldShow(
            isProUser: false,
            hasDismissedExplainer: hasDismissedExplainer,
            isInterstitialEligibleToday: true
        ))
        #expect(!AdExplainerPresentationPolicy.shouldShow(
            isProUser: false,
            hasDismissedExplainer: hasDismissedExplainer,
            isInterstitialEligibleToday: true,
            preGameInterstitialsEnabled: false
        ))
    }

    @Test("Explanation settings follow the pre-game switch")
    func explanationSettingsVisibility() {
        #expect(!AdExplainerPresentationPolicy.shouldOfferExplanationSetting(
            preGameInterstitialsEnabled: false
        ))
        #expect(AdExplainerPresentationPolicy.shouldOfferExplanationSetting(
            preGameInterstitialsEnabled: true
        ))
    }

    @Test("Paused Pro copy describes hints and hides the full-experience benefit")
    func pausedProBenefits() {
        let content = ProAdBenefitsContent()

        #expect(content.homeTitle == "Ad-free hints")
        #expect(content.settingsFooter == "Subscribe for ad-free hints, weekly crossword and all archive games.")
        #expect(!content.showsAdFreeExperienceBenefit)
    }

    @Test("Re-enabling pre-game ads restores the original Pro copy")
    func enabledProBenefits() {
        let content = ProAdBenefitsContent(preGameInterstitialsEnabled: true)

        #expect(content.homeTitle == "Ad-free experience")
        #expect(content.settingsFooter == "Subscribe to remove ads, access weekly crossword and all archive games.")
        #expect(content.showsAdFreeExperienceBenefit)
    }
}
