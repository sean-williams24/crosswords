import Combine
import Foundation

/// Presentation timing only; Home owns eligibility and acknowledgement.
@MainActor
final class DailyChallengeCelebrationViewModel: ObservableObject {
    @Published private(set) var step = 0
    private let pause: (Duration) async throws -> Void

    init(pause: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.pause = pause
    }

    var showsTotal: Bool { step == Self.finalStep }

    func showsGame(_ game: DailyChallengeGame) -> Bool {
        step >= index(of: game) * 2 + 1
    }

    func showsPoints(_ game: DailyChallengeGame) -> Bool {
        step >= index(of: game) * 2 + 2
    }

    func reveal(reduceMotion: Bool) async {
        guard !reduceMotion else {
            step = Self.finalStep
            return
        }
        step = 0
        do {
            try await pause(.milliseconds(300))
            for next in 1...Self.finalStep {
                try Task.checkCancellation()
                step = next
                if next < Self.finalStep {
                    // Give each logo a beat before revealing its earned points.
                    try await pause(.milliseconds(next.isMultiple(of: 2) ? 450 : 300))
                }
            }
        } catch {
            // The view's task is cancelled when the card is dismissed.
        }
    }

    private static var finalStep: Int { DailyChallengeGame.allCases.count * 2 + 1 }

    private func index(of game: DailyChallengeGame) -> Int {
        DailyChallengeGame.allCases.firstIndex(of: game)!
    }
}
