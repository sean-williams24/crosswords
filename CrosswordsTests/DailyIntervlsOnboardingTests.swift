import Foundation
import Testing
@testable import Backword

@MainActor
@Suite("Daily Intervls onboarding")
struct DailyIntervlsOnboardingTests {
    @Test("A fresh installation offers gameplay after Home is ready, even offline")
    func freshInstallation() {
        withDefaults { defaults in
            let onboarding = DailyIntervlsOnboardingViewModel(defaults: defaults, legacyAppDataExists: false)
            #expect(onboarding.firstLaunchStep == .gameplay)
            #expect(onboarding.homeOffer(isHomeReady: false, hasGameLoadError: false) == nil)
            #expect(onboarding.homeOffer(isHomeReady: true, hasGameLoadError: false) == .firstLaunch(.gameplay))
            #expect(onboarding.homeOffer(isHomeReady: true, hasGameLoadError: true) == .firstLaunch(.gameplay))
            #expect(!onboarding.showsReturningTip)
        }
    }

    @Test("Gameplay acknowledgement survives an interruption even after startup has written data")
    func resumeScoring() {
        withDefaults { defaults in
            let onboarding = DailyIntervlsOnboardingViewModel(defaults: defaults, legacyAppDataExists: false)
            onboarding.finishOnboarding()
            #expect(onboarding.firstLaunchStep == .gameplay)
            onboarding.acknowledgeGameplay()

            let relaunched = DailyIntervlsOnboardingViewModel(defaults: defaults, legacyAppDataExists: true)
            #expect(relaunched.firstLaunchStep == .scoring)
            #expect(relaunched.homeOffer(isHomeReady: true, hasGameLoadError: true) == .firstLaunch(.scoring))
        }
    }

    @Test("Finishing the scoring page completes onboarding for later launches")
    func completeOnboarding() {
        withDefaults { defaults in
            let onboarding = DailyIntervlsOnboardingViewModel(defaults: defaults, legacyAppDataExists: false)
            onboarding.acknowledgeGameplay()
            onboarding.finishOnboarding()

            let relaunched = DailyIntervlsOnboardingViewModel(defaults: defaults, legacyAppDataExists: true)
            #expect(relaunched.firstLaunchStep == nil)
            #expect(relaunched.homeOffer(isHomeReady: true, hasGameLoadError: false) == nil)
            #expect(!relaunched.showsReturningTip)
        }
    }

    @Test("Stored legacy preferences count as prior use, including a false choice",
          arguments: ["hasSeenDailyCrosswordOnboarding", AnalyticsConsent.storageKey, "appColorScheme"])
    func legacyPreferences(key: String) {
        withDefaults { defaults in
            defaults.set(false, forKey: key)
            let onboarding = DailyIntervlsOnboardingViewModel(defaults: defaults, legacyAppDataExists: false)
            #expect(onboarding.firstLaunchStep == nil)
            #expect(onboarding.homeOffer(isHomeReady: true, hasGameLoadError: false) == .returningTip)
        }
    }

    @Test("The returning tip waits for an eligible Home and appears only in that session")
    func returningTip() {
        withDefaults { defaults in
            let onboarding = DailyIntervlsOnboardingViewModel(defaults: defaults, legacyAppDataExists: true)
            #expect(onboarding.firstLaunchStep == nil)
            #expect(onboarding.homeOffer(isHomeReady: false, hasGameLoadError: false) == nil)
            #expect(onboarding.homeOffer(isHomeReady: true, hasGameLoadError: true) == nil)

            // Waiting for Home to become eligible has not consumed the tip on relaunch.
            let relaunched = DailyIntervlsOnboardingViewModel(defaults: defaults, legacyAppDataExists: true)
            #expect(relaunched.homeOffer(isHomeReady: true, hasGameLoadError: false) == .returningTip)
            relaunched.presentReturningTip()
            #expect(relaunched.showsReturningTip)
            #expect(relaunched.homeOffer(isHomeReady: true, hasGameLoadError: false) == nil)

            let nextLaunch = DailyIntervlsOnboardingViewModel(defaults: defaults, legacyAppDataExists: true)
            #expect(!nextLaunch.showsReturningTip)
            #expect(nextLaunch.homeOffer(isHomeReady: true, hasGameLoadError: false) == nil)

            relaunched.dismissReturningTip()
            relaunched.presentReturningTip()
            #expect(!relaunched.showsReturningTip)
        }
    }

    @Test("Manual opening starts on gameplay, while onboarding can resume at scoring")
    func guideModes() {
        let manual = DailyIntervlsGuideView.Mode.manual
        let resumed = DailyIntervlsGuideView.Mode.onboarding(.scoring)
        #expect(manual.startingStep == .gameplay)
        #expect(resumed.startingStep == .scoring)
        #expect(DailyIntervlsGuideStep.gameplay.actionTitle(isOnboarding: resumed.isOnboarding) == "OK")
        #expect(DailyIntervlsGuideStep.scoring.actionTitle(isOnboarding: resumed.isOnboarding) == "Lets play")
        #expect(DailyIntervlsGuideStep.scoring.actionTitle(isOnboarding: manual.isOnboarding) == "Done")
    }

    @Test("The lineup uses Home order and the scoring page explains the rating window")
    func guideContent() {
        #expect(DailyChallengeGame.allCases.map(\.displayName) == ["Backword", "Quick Crossword", "Anagram", "Midword"])
        #expect(DailyIntervlsGuideStep.gameplay.introduction ==
                "Finish all four daily games before midnight, score a maximum of 20 points.")

        let ratingIntroduction = DailyIntervlsGuideStep.scoring.introduction
        #expect(ratingIntroduction.contains("last \(OverallRating.windowDays) days, including today"))
        #expect(DailyIntervlsGuideStep.ratingWindowDescription ==
                "Each new day replaces the oldest. Missed games score zero.")
    }

    @Test("The example goes from zero to the full 14-day rating maximum", arguments: [false, true])
    func ratingExampleTotals(isPro: Bool) {
        let initial = DailyIntervlsRatingExample(fraction: -0.1, isPro: isPro)
        let final = DailyIntervlsRatingExample(fraction: 1.1, isPro: isPro)
        let fullWindow = OverallRating().maxPoints(
            isPro: isPro, now: Date(timeIntervalSince1970: 1_800_000_000),
            firstAnagramRelease: OverallRating.midwordLaunchDate
        )

        #expect(initial.fraction == 0)
        #expect(initial.points == 0)
        #expect(initial.tier == .novice)
        #expect(final.fraction == 1)
        #expect(final.maximumPoints == fullWindow)
        #expect(final.points == fullWindow)
        #expect(final.tier == .virtuoso)
    }

    @Test("The example shows the next tier when its displayed points reach the rating threshold",
          arguments: [RatingTier.scribe, .linguist, .grandmaster, .virtuoso], [false, true])
    func ratingExampleTier(tier: RatingTier, isPro: Bool) {
        let maximum = Double(DailyIntervlsRatingExample(fraction: 1, isPro: isPro).maximumPoints)
        let qualifyingPoints = ceil(tier.threshold * maximum)
        let firstQualifyingScore = DailyIntervlsRatingExample(fraction: (qualifyingPoints + 0.25) / maximum, isPro: isPro)
        let lastLowerScore = DailyIntervlsRatingExample(fraction: (qualifyingPoints - 0.25) / maximum, isPro: isPro)

        #expect(firstQualifyingScore.tier == tier)
        #expect(firstQualifyingScore.points == Int(qualifyingPoints))
        #expect(lastLowerScore.points == firstQualifyingScore.points - 1)
        #expect(lastLowerScore.tier.nextThreshold == tier.threshold)
    }

    private func withDefaults(_ test: (UserDefaults) -> Void) {
        let name = "DailyIntervlsOnboardingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        test(defaults)
    }
}
