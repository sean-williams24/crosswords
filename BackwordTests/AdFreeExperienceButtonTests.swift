import Testing
@testable import Backword

@Suite("Ad free experience button")
struct AdFreeExperienceButtonTests {
    @Test("Home content promotes archive access for all five games")
    func homeContentCopy() {
        let content = AdFreeExperienceButtonContent.home

        #expect(content.title == "ARCHIVE")
        #expect(content.detail == "Unlock the archive for all 5 games")
        #expect(content.subtitle == "Go Pro")
        #expect(content.systemImage == "archivebox")
        #expect(content.accessibilityLabel == "ARCHIVE, Unlock the archive for all 5 games, Go Pro")
    }

    @Test("Ad explainer content keeps the ad-free call to action")
    func adExplainerContentCopy() {
        let content = AdFreeExperienceButtonContent.adExplainer

        #expect(content.title == "Ad-free experience")
        #expect(content.detail == "Archive access")
        #expect(content.subtitle == "Go Pro")
        #expect(content.systemImage == "sparkles")
        #expect(content.accessibilityLabel == "Ad-free experience, Archive access, Go Pro")
    }

    @Test("Visibility waits for subscription status before showing free user CTA")
    func visibilityWaitsForSubscriptionStatus() {
        #expect(!AdFreeExperienceButtonVisibility.shouldShow(isProUser: false, subscriptionStatusLoaded: false))
        #expect(!AdFreeExperienceButtonVisibility.shouldShow(isProUser: true, subscriptionStatusLoaded: false))
        #expect(!AdFreeExperienceButtonVisibility.shouldShow(isProUser: true, subscriptionStatusLoaded: true))
        #expect(AdFreeExperienceButtonVisibility.shouldShow(isProUser: false, subscriptionStatusLoaded: true))
    }

    @Test("Archive card has a lighter surface in Light Mode")
    func archiveCardLightModeBackground() {
        let lightOpacity = AdFreeExperienceButtonAppearance.backgroundOpacity(for: .light, isArchiveCard: true)
        let darkOpacity = AdFreeExperienceButtonAppearance.backgroundOpacity(for: .dark, isArchiveCard: true)

        #expect(lightOpacity == 0.5)
        #expect(darkOpacity == 0.26)
        #expect(lightOpacity > darkOpacity)
    }

    @Test("Ad explainer retains its existing surface in both appearances")
    func adExplainerBackground() {
        #expect(AdFreeExperienceButtonAppearance.backgroundOpacity(for: .light, isArchiveCard: false) == 0.26)
        #expect(AdFreeExperienceButtonAppearance.backgroundOpacity(for: .dark, isArchiveCard: false) == 0.26)
    }
}
