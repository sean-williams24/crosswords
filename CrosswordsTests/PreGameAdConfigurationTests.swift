import Testing
@testable import Backword

@Suite("Pre-game ad configuration")
struct PreGameAdConfigurationTests {
    @Test("Pre-game ads are disabled by default")
    func disabledByDefault() {
        #expect(!AdConfiguration.adsEnabled)
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

    @Test("Paused Pro copy promotes archive access and hides all ad benefits")
    func pausedProBenefits() {
        let content = ProAdBenefitsContent()

        #expect(content.homeTitle == "Archive access")
        #expect(!content.showsAdFreeHintsBenefit)
        #expect(content.settingsFooter == "Subscribe for weekly crossword and all archive games.")
        #expect(!content.showsAdFreeExperienceBenefit)
    }

    @Test("Restoring rewarded ads alone restores only the hint benefit")
    func rewardedOnlyBenefits() {
        let content = ProAdBenefitsContent(adsEnabled: true, preGameInterstitialsEnabled: false)
        #expect(content.homeTitle == "Ad-free hints")
        #expect(content.settingsFooter == "Subscribe for ad-free hints, weekly crossword and all archive games.")
        #expect(content.showsAdFreeHintsBenefit)
        #expect(!content.showsAdFreeExperienceBenefit)
    }

    @Test("Master pause suppresses benefits even with pre-game ads configured")
    func masterPauseSuppressesBenefits() {
        let content = ProAdBenefitsContent(adsEnabled: false, preGameInterstitialsEnabled: true)
        #expect(!content.showsAdFreeHintsBenefit)
        #expect(!content.showsAdFreeExperienceBenefit)
        #expect(!content.settingsFooter.contains("ad-free"))
    }

    @Test("Crossword instructions offer give-up without a Pro restriction")
    @MainActor
    func giveUpInstructionsAreAvailableToEveryone() {
        #expect(DailyCrosswordInstructionsContentView.giveUpInstructions == "Tap the flag to give up and reveal the answers.")
    }

    @Test("Instructions follow the rewarded ads setting")
    @MainActor
    func hintInstructions() {
        #expect(DailyCrosswordInstructionsContentView.hintInstructions() == "Tap Hint to reveal an alternate clue.")
        #expect(AnagramInstructionsContentView.hintInstructions() == "Revealing a letter adds 30 seconds to your scoring time.")
        #expect(DailyCrosswordInstructionsContentView.hintInstructions(rewardedAdsEnabled: true).contains("watch an ad"))
        #expect(AnagramInstructionsContentView.hintInstructions(rewardedAdsEnabled: true).contains("rewarded ad"))
    }

    @Test("Re-enabling pre-game ads restores the original Pro copy")
    func enabledProBenefits() {
        let content = ProAdBenefitsContent(adsEnabled: true, preGameInterstitialsEnabled: true)

        #expect(content.homeTitle == "Ad-free experience")
        #expect(content.settingsFooter == "Subscribe to remove ads, access weekly crossword and all archive games.")
        #expect(content.showsAdFreeExperienceBenefit)
    }
}
