import Foundation
import Testing
@testable import Backword

@MainActor
@Suite("Paused pre-game ad service")
struct PreGameAdServiceTests {
    @Test("Default service disables pre-game ads")
    func defaultServiceDisablesPreGameAds() {
        let service = AdService(adConsentService: UnavailableHintAdConsentService())

        #expect(!service.preGameInterstitialsEnabled)
        #expect(!service.canShowInterstitialToday(for: .backwordOpen))
        #expect(!service.canShowInterstitialToday(for: .dailyPuzzleOpen))
    }

    @Test("Paused requests continue once without startup or history changes", arguments:
        [AdService.UserDefaultsKey.backwordOpen, .dailyPuzzleOpen], [false, true])
    func pausedRequestsContinueWithoutSideEffects(
        placement: AdService.UserDefaultsKey,
        hasPreviousImpression: Bool
    ) async {
        let suiteName = "PreGameAdServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gate = InterstitialPresentationGate(userDefaults: defaults)
        if hasPreviousImpression {
            gate.markPresented(type: placement)
        }
        let previousImpression = defaults.object(forKey: gate.key(for: placement)) as? Date
        let consentService = UnavailableHintAdConsentService()
        let service = AdService(
            interstitialGate: gate,
            adConsentService: consentService,
            preGameInterstitialsEnabled: false
        )
        #if DEBUG
        service.debugAdsEnabled = true
        #endif
        var continuationCount = 0

        service.showInterstitialOnce(for: placement) {
            continuationCount += 1
        }
        #expect(continuationCount == 1)
        service.showInterstitial()
        let didLoad = await service.loadAd()
        // Allow any erroneously scheduled startup/continuation task to run.
        for _ in 0..<10 {
            await Task.yield()
        }

        #expect(!didLoad)
        #expect(continuationCount == 1)
        #expect(consentService.prepareCallCount == 0)
        #expect(consentService.updateCallCount == 0)
        #expect(!service.adStartupDidComplete)
        #expect(!service.isPresentingFullScreenAd)
        #expect(!service.canShowInterstitialToday(for: placement))
        #expect((defaults.object(forKey: gate.key(for: placement)) as? Date) == previousImpression)
    }

    @Test("Paused games bypass the gate regardless of Pro or onboarding", arguments: [false, true], [false, true])
    func pausedGamesBypassGate(isProUser: Bool, hasSeenRequiredOnboarding: Bool) {
        let service = AdService(
            adConsentService: UnavailableHintAdConsentService(),
            preGameInterstitialsEnabled: false
        )

        #expect(!service.shouldUsePreGameAdGate(
            isProUser: isProUser,
            hasSeenRequiredOnboarding: hasSeenRequiredOnboarding
        ))
    }

    @Test("Re-enabled gate preserves Pro and onboarding rules", arguments: [false, true], [false, true])
    func enabledGatePreservesRules(isProUser: Bool, hasSeenRequiredOnboarding: Bool) {
        let service = AdService(
            adConsentService: UnavailableHintAdConsentService(),
            preGameInterstitialsEnabled: true
        )

        #expect(service.shouldUsePreGameAdGate(
            isProUser: isProUser,
            hasSeenRequiredOnboarding: hasSeenRequiredOnboarding
        ) == (!isProUser && hasSeenRequiredOnboarding))
    }

    @Test("Rewarded hints still attempt consent and complete when unavailable")
    func rewardedHintStillStartsAndCompletes() async {
        let consentService = UnavailableHintAdConsentService()
        let service = AdService(adConsentService: consentService, preGameInterstitialsEnabled: false)
        #if DEBUG
        service.debugAdsEnabled = true
        #endif
        var completionCount = 0

        await service.refreshConsentStatusIfNeeded()
        #expect(consentService.updateCallCount == 1)
        #expect(consentService.prepareCallCount == 0)

        let result = await withCheckedContinuation { continuation in
            service.showRewardedAd { result in
                completionCount += 1
                continuation.resume(returning: result)
            }
        }

        guard case .unavailable = result else {
            Issue.record("Expected an unavailable rewarded hint when consent preparation fails")
            return
        }
        #expect(completionCount == 1)
        #expect(consentService.prepareCallCount == 1)
        #expect(consentService.updateCallCount == 1)
        #expect(service.adStartupDidComplete)
        #expect(!service.isPresentingFullScreenAd)
        #expect(!service.rewardGranted)
    }
}

@MainActor
private final class UnavailableHintAdConsentService: AdConsentPreparing {
    let privacyOptionsRequirementStatus: AdPrivacyOptionsRequirementStatus = .notRequired
    private(set) var prepareCallCount = 0
    private(set) var updateCallCount = 0

    func updateConsentInfo() async -> Bool {
        updateCallCount += 1
        return true
    }

    func prepareForAds() async -> Bool {
        prepareCallCount += 1
        return false
    }

    func presentPrivacyOptionsForm() async {}
}
