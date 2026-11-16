import Foundation
import Testing
@testable import Backword

@MainActor
@Suite("Paused pre-game ad service")
struct PreGameAdServiceTests {
    @Test("Master pause blocks all ad work even when pre-game ads are enabled", arguments: [false, true])
    func masterPauseBlocksAdWork(preGameEnabled: Bool) async {
        let suiteName = "PausedAds.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gate = InterstitialPresentationGate(userDefaults: defaults)
        gate.markPresented(type: .backwordOpen)
        let previousImpression = defaults.object(forKey: gate.key(for: .backwordOpen)) as? Date
        let consent = UnavailableHintAdConsentService()
        let service = AdService(
            interstitialGate: gate,
            adConsentService: consent,
            adsEnabled: false,
            preGameInterstitialsEnabled: preGameEnabled
        )
        #expect(service.adStartupDidComplete)
        #expect(!service.preGameInterstitialsEnabled)
        #expect(!service.shouldUsePreGameAdGate(isProUser: false, hasSeenRequiredOnboarding: true))
        #expect(!service.canShowInterstitialToday(for: .dailyPuzzleOpen))
        await service.refreshConsentStatusIfNeeded()
        service.refreshPrivacyOptionsRequirement()
        await service.presentPrivacyOptionsForm()
        #expect(!(await service.prepareAdsIfNeeded()))
        #expect(!(await service.loadAd()))
        await service.loadRewardedAd()
        service.showInterstitial()
        var navigationCount = 0
        service.showInterstitialOnce(for: .dailyPuzzleOpen) { navigationCount += 1 }
        var rewardedCompletionCount = 0
        service.showRewardedAd { result in
            rewardedCompletionCount += 1
            guard case .unavailable = result else {
                Issue.record("Paused ads must return unavailable")
                return
            }
        }
        for _ in 0..<10 { await Task.yield() }
        #expect(navigationCount == 1)
        #expect(rewardedCompletionCount == 1)
        #expect(consent.updateCallCount == 0)
        #expect(consent.prepareCallCount == 0)
        #expect(consent.privacyOptionsCallCount == 0)
        #expect(!service.isPrivacyOptionsRequired)
        #expect(!service.isPresentingFullScreenAd)
        #expect(!service.rewardGranted)
        #expect((defaults.object(forKey: gate.key(for: .backwordOpen)) as? Date) == previousImpression)
        #expect(SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: true,
            navigationBarDidAppear: true,
            adStartupDidComplete: service.adStartupDidComplete,
            isPresentingFullScreenAd: service.isPresentingFullScreenAd,
            isHomeNavigationActive: false,
            didReturnFromDailyGame: true
        ))
    }

    @Test("Default service disables pre-game ads")
    func defaultServiceDisablesPreGameAds() {
        let service = AdService(adConsentService: UnavailableHintAdConsentService())

        #expect(!service.adsEnabled)
        #expect(service.adStartupDidComplete)
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
            adsEnabled: true,
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
            adsEnabled: true,
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
            adsEnabled: true,
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
        let service = AdService(adConsentService: consentService, adsEnabled: true, preGameInterstitialsEnabled: false)
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
    let privacyOptionsRequirementStatus: AdPrivacyOptionsRequirementStatus = .required
    private(set) var prepareCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var privacyOptionsCallCount = 0

    func updateConsentInfo() async -> Bool {
        updateCallCount += 1
        return true
    }

    func prepareForAds() async -> Bool {
        prepareCallCount += 1
        return false
    }

    func presentPrivacyOptionsForm() async { privacyOptionsCallCount += 1 }
}
