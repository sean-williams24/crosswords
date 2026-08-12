import Foundation

@MainActor
final class BackwordStatsService: ObservableObject {
    @Published private(set) var stats: BackwordStats = BackwordStats()

    func refresh() {
        guard ProgressStorageNamespace.accountID != nil else {
            stats = BackwordStats.load()
            return
        }

        stats = BackwordStats.rebuiltForAccount(progressRecords: BackwordProgress.loadAll())
    }
}

extension BackwordStats {
    /// Account metrics are derived only from canonical release-day results.
    /// Archive progress remains synced but never changes lifetime performance
    /// metrics such as wins, streaks, win rate, or guess distribution.
    static func rebuiltForAccount(
        progressRecords: [BackwordProgress],
        calendar: Calendar = .current
    ) -> BackwordStats {
        var rebuilt = BackwordStats()
        for progress in progressRecords
            .filter({ progress in
                guard progress.isComplete, let completedAt = progress.completedAt else { return false }
                return ContentReleaseCalendar(now: completedAt, calendar: calendar).dailyDateString == progress.date
            })
            .sorted(by: { $0.date < $1.date }) {
            rebuilt.record(
                guessCount: progress.isWon ? progress.guesses.count : nil,
                date: progress.date
            )
        }
        return rebuilt
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
