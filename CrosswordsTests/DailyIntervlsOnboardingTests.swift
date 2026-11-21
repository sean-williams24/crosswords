import Foundation
import SwiftUI
import Testing
@testable import Backword

@MainActor
@Suite("Daily Intervls onboarding")
struct DailyIntervlsOnboardingTests {
    @Test("A fresh installation offers gameplay after Home is ready")
    func freshInstallation() {
        withDefaults { defaults in
            let onboarding = DailyIntervlsOnboardingViewModel(defaults: defaults)
            #expect(onboarding.pendingStep == .gameplay)
            #expect(onboarding.homeStep(isReady: false) == nil)
            #expect(onboarding.homeStep(isReady: true) == .gameplay)
        }
    }

    @Test("Gameplay acknowledgement survives an interruption")
    func resumeScoring() {
        withDefaults { defaults in
            let onboarding = DailyIntervlsOnboardingViewModel(defaults: defaults)
            onboarding.finishOnboarding()
            #expect(onboarding.pendingStep == .gameplay)
            onboarding.acknowledgeGameplay()

            let relaunched = DailyIntervlsOnboardingViewModel(defaults: defaults)
            #expect(relaunched.homeStep(isReady: true) == .scoring)
        }
    }

    @Test("Finishing the scoring page completes onboarding for later launches")
    func completeOnboarding() {
        withDefaults { defaults in
            let onboarding = DailyIntervlsOnboardingViewModel(defaults: defaults)
            onboarding.acknowledgeGameplay()
            onboarding.finishOnboarding()

            let relaunched = DailyIntervlsOnboardingViewModel(defaults: defaults)
            #expect(relaunched.homeStep(isReady: true) == nil)
        }
    }

    @Test("Installations with existing preferences get the gameplay walkthrough",
          arguments: ["hasSeenDailyCrosswordOnboarding", AnalyticsConsent.storageKey, "appColorScheme"])
    func legacyPreferences(key: String) {
        withDefaults { defaults in
            defaults.set(false, forKey: key)
            let onboarding = DailyIntervlsOnboardingViewModel(defaults: defaults)
            #expect(onboarding.homeStep(isReady: true) == .gameplay)
        }
    }

    @Test("A previously pending returning tip enters the full walkthrough")
    func legacyPendingTip() {
        withDefaults { defaults in
            defaults.set("returningTipPending", forKey: "dailyIntervls.onboarding.v1")
            let onboarding = DailyIntervlsOnboardingViewModel(defaults: defaults)
            #expect(onboarding.homeStep(isReady: true) == .gameplay)
            onboarding.acknowledgeGameplay()
            #expect(onboarding.homeStep(isReady: true) == .scoring)
            onboarding.finishOnboarding()
            #expect(onboarding.homeStep(isReady: true) == nil)
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

    @Test("Advancing the guide suppresses inherited and implicit layout animations")
    func guidePageAdvanceDisablesAnimations() {
        let transaction = DailyIntervlsGuideView.pageAdvanceTransaction
        #expect(transaction.animation == nil)
        #expect(transaction.disablesAnimations)
    }

    @Test("The lineup uses Home order and the scoring page has three separate rating points")
    func guideContent() {
        #expect(DailyChallengeGame.allCases.map(\.displayName) == ["Backword", "Quick Crossword", "Anagram", "Midword"])
        #expect(DailyIntervlsGuideStep.gameplayIntroduction ==
                "Complete all four daily games before midnight, score a maximum of 20 points.")

        let points = DailyIntervlsGuideStep.ratingBulletPoints
        #expect(points == [
            "Your rating is based on the points you earned over the last \(OverallRating.windowDays) days.",
            "Complete your Intervls everyday to reach the highest tier and stay there.",
            "Each new day replaces the oldest."
        ])
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

    @Test("Tier labels crossfade as progress passes the qualifying score",
          arguments: [RatingTier.scribe, .linguist, .grandmaster, .virtuoso], [false, true])
    func ratingExampleLabelFade(tier: RatingTier, isPro: Bool) {
        let maximum = Double(DailyIntervlsRatingExample(fraction: 1, isPro: isPro).maximumPoints)
        let qualifyingPoints = ceil(tier.threshold * maximum)
        let previousTier = RatingTier.forFraction((qualifyingPoints - 1) / maximum)
        let startFraction = qualifyingPoints / maximum
        let start = DailyIntervlsRatingExample(fraction: startFraction, isPro: isPro)
        let midpoint = DailyIntervlsRatingExample(fraction: startFraction + 0.025, isPro: isPro)
        let end = DailyIntervlsRatingExample(fraction: startFraction + 0.05, isPro: isPro)

        #expect(start.labelOpacity(for: previousTier) == 1)
        #expect(start.labelOpacity(for: tier) == 0)
        #expect(abs(midpoint.labelOpacity(for: previousTier) - 0.5) < 0.0001)
        #expect(abs(midpoint.labelOpacity(for: tier) - 0.5) < 0.0001)
        #expect(end.labelOpacity(for: previousTier) == 0)
        #expect(end.labelOpacity(for: tier) == 1)
    }

    @Test("Finishing the guide dismisses immediately and only records completion during onboarding",
          arguments: [false, true])
    func finishGuide(isOnboarding: Bool) {
        var actions: [String] = []
        let guide = DailyIntervlsGuideView(
            mode: isOnboarding ? .onboarding(.scoring) : .manual,
            finishOnboarding: { actions.append("complete") },
            dismiss: { actions.append("dismiss") }
        )

        guide.finishGuide()

        #expect(actions == (isOnboarding ? ["complete", "dismiss"] : ["dismiss"]))
    }

    private func withDefaults(_ test: (UserDefaults) -> Void) {
        let name = "DailyIntervlsOnboardingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        test(defaults)
    }
}
