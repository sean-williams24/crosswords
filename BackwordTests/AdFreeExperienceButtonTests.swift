import Testing
@testable import Backword

@Suite("Ad free experience button")
struct AdFreeExperienceButtonTests {
    @Test("Home content uses paywall call to action copy")
    func homeContentCopy() {
        let content = AdFreeExperienceButtonContent.home

        #expect(content.title == "Ad free experience")
        #expect(content.detail == "Archive access")
        #expect(content.subtitle == "Go Pro")
        #expect(content.systemImage == "sparkles")
        #expect(content.accessibilityLabel == "Ad free experience, Archive access, Go Pro")
    }

    @Test("Visibility waits for subscription status before showing free user CTA")
    func visibilityWaitsForSubscriptionStatus() {
        #expect(!AdFreeExperienceButtonVisibility.shouldShow(isProUser: false, subscriptionStatusLoaded: false))
        #expect(!AdFreeExperienceButtonVisibility.shouldShow(isProUser: true, subscriptionStatusLoaded: false))
        #expect(!AdFreeExperienceButtonVisibility.shouldShow(isProUser: true, subscriptionStatusLoaded: true))
        #expect(AdFreeExperienceButtonVisibility.shouldShow(isProUser: false, subscriptionStatusLoaded: true))
    }
}
