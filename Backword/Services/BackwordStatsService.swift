import Foundation

@MainActor
final class BackwordStatsService: ObservableObject {
    @Published private(set) var stats: BackwordStats = BackwordStats()

    func refresh() {
        stats = BackwordStats.load()
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
