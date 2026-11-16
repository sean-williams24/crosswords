import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Anagram hint banner")
struct AnagramHintBannerTests {
    @Test("Paused ads give every player the time-penalty confirmation", arguments: [false, true])
    func pausedHintChoices(isProUser: Bool) {
        let mode = AnagramHintBannerMode(isProUser: isProUser)
        #expect(mode == .timePenalty)
        #expect(mode.title == "Reveal a letter?")
        #expect(mode.primaryButtonTitle == "Reveal letter")
        #expect(mode.subtitle == "Reveal one letter with a 30-second penalty.")
        #expect(!mode.showsAdFreeButton)
    }

    @Test("Free players can watch an ad or open the ad-free paywall")
    func freePlayerChoices() {
        let mode = AnagramHintBannerMode(isProUser: false, rewardedAdsEnabled: true)

        #expect(mode == .watchAd)
        #expect(mode.primaryButtonTitle == "Watch")
        #expect(mode.showsAdFreeButton)
    }

    @Test("Pro players confirm a time penalty without an ad-free offer", arguments: [false, true])
    func proPlayerChoice(rewardedAdsEnabled: Bool) {
        let mode = AnagramHintBannerMode(isProUser: true, rewardedAdsEnabled: rewardedAdsEnabled)

        #expect(mode == .timePenalty)
        #expect(mode.primaryButtonTitle == "Reveal letter")
        #expect(mode.subtitle == "Reveal one letter with a 30-second penalty.")
        #expect(!mode.showsAdFreeButton)
    }

    @Test("An unavailable ad offers the time penalty without granting a hint")
    func unavailableAdChoice() {
        #expect(AnagramHintAdAction(result: .unavailable) == .offerTimePenalty)
        #expect(AnagramHintAdAction(result: .failedToPresent) == .offerTimePenalty)
        #expect(AnagramHintBannerMode.adUnavailable.showsAdFreeButton)
    }

    @Test("Only an earned ad reward reveals the free letter")
    func rewardOutcomes() {
        #expect(AnagramHintAdAction(result: .earnedReward) == .reveal)
        #expect(AnagramHintAdAction(result: .dismissedWithoutReward) == .close)
    }

    @Test("A long fallback message keeps the banner's full height on a narrow phone")
    func bannerDoesNotCompressBelowItsContent() {
        let banner = AnagramHintBanner(
            mode: .adUnavailable,
            narrowsAnswers: false,
            isBusy: false,
            onPrimaryAction: {},
            onGoAdFree: {},
            onClose: {}
        )
        let host = UIHostingController(rootView: banner)
        let width: CGFloat = 320
        let fullHeight = host.sizeThatFits(in: CGSize(width: width, height: 10_000)).height
        let constrainedSize = host.sizeThatFits(in: CGSize(width: width, height: 80))

        #expect(constrainedSize.width <= width + 0.5)
        #expect(constrainedSize.height >= fullHeight - 0.5)
    }
}
