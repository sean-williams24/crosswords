import Foundation

@MainActor
final class BackwordStatsService: ObservableObject {
    @Published private(set) var stats: BackwordStats = BackwordStats()

    func refresh() {
        guard ProgressStorageNamespace.accountID != nil else {
            stats = BackwordStats.load()
            return
        }

        var rebuilt = BackwordStats()
        for progress in BackwordProgress.loadAll().filter(\.isComplete).sorted(by: { $0.date < $1.date }) {
            rebuilt.record(
                guessCount: progress.isWon ? progress.guesses.count : nil,
                date: progress.date
            )
        }
        stats = rebuilt
    }
}

// MARK: - Convenience extensions for BackwordStatsView

extension BackwordStats {
    var winRate: Int {
        guard gamesPlayed > 0 else { return 0 }
        return Int((Double(gamesWon) / Double(gamesPlayed)) * 100)
    }

    /// Ordered count for guess number (1-based), falling back to 0.
    func count(forGuess guess: Int) -> Int {
        guessCounts["\(guess)"] ?? 0
    }

    var maxGuessCount: Int {
        (1...5).map { count(forGuess: $0) }.max() ?? 1
    }
}
