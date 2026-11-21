import SwiftUI

struct DailyIntervlsLineupView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = HomeDailyChallengeCelebrationRow.RevealPhase.hidden
    var snapshot: DailyChallengeSnapshot? = nil

    var body: some View {
        let visiblePhase = reduceMotion ? .points : phase
        VStack(spacing: AppLayout.homeDailyCelebrationRowSpacing) {
            ForEach(Array(DailyChallengeGame.allCases.enumerated()), id: \.element.id) { index, game in
                let delay = Double(index) * 0.14
                row(for: game, phase: visiblePhase, delay: delay)
                    .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.72).delay(delay),
                               value: visiblePhase != .hidden)
            }
        }
        .task(id: reduceMotion) { await reveal() }
    }

    private func row(for game: DailyChallengeGame, phase: HomeDailyChallengeCelebrationRow.RevealPhase,
                     delay: Double) -> HomeDailyChallengeCelebrationRow {
        if let snapshot {
            return HomeDailyChallengeCelebrationRow(progress: snapshot[game], profilePhase: phase, delay: delay)
        }
        return HomeDailyChallengeCelebrationRow(game: game, guidePhase: phase, delay: delay)
    }

    private func reveal() async {
        guard !reduceMotion, phase != .points else { return }
        phase = .hidden
        do {
            try await Task.sleep(for: .milliseconds(120))
            phase = .marker
            try await Task.sleep(for: .milliseconds(220))
            phase = .filled
            try await Task.sleep(for: .milliseconds(HomeDailyChallengeCelebrationRow.markerFillMilliseconds + 120))
            phase = .points
        } catch {
            // Leaving the lineup cancels the reveal.
        }
    }
}
