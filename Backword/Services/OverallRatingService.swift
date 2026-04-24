import Foundation

@MainActor
final class OverallRatingService: ObservableObject {
    @Published private(set) var rating: OverallRating = .load()

    // MARK: - Refresh

    func refresh() {
        rating = .load()
        backfillFromDisk()
    }

    // MARK: - Backfill from disk

    private func backfillFromDisk() {
        let cutoff = OverallRating.dateFormatter.string(
            from: Calendar.current.date(byAdding: .day, value: -13, to: Calendar.current.startOfDay(for: Date()))!
        )

        // Backword
        for bw in BackwordProgress.loadAll() where bw.date >= cutoff {
            guard bw.isComplete else { continue }
            let score = bw.isWon ? Int.backwordScore(guessCount: bw.guesses.count) : 0
            rating.upsertBackword(score: score, date: bw.date)
        }

        // Crosswords — scan all progress files that have metadata
        for p in UserProgress.loadAll() {
            guard let date = p.puzzleDate, date >= cutoff,
                  let total = p.totalClues, total > 0 else { continue }
            let completed = p.completedClueIds.count
            let pct = Int(Double(completed) / Double(total) * 100)
            let score = Int.crosswordScore(percentComplete: pct)
            if p.isWeekly == true {
                rating.upsertWeeklyCrossword(score: score, date: date)
            } else {
                rating.upsertDailyCrossword(score: score, date: date)
            }
        }

        rating.save()
    }

    /// Records progress for the currently loaded daily and/or weekly puzzle,
    /// then backfills all historical scores from disk.
    func recordCurrentPuzzles(daily: Puzzle?, weekly: Puzzle?) {
        if let puzzle = daily {
            let progress = UserProgress.load(puzzleId: puzzle.id)
            let completed = progress?.completedClueIds.count ?? 0
            let pct = puzzle.clues.count > 0 ? Int(Double(completed) / Double(puzzle.clues.count) * 100) : 0
            rating.upsertDailyCrossword(score: Int.crosswordScore(percentComplete: pct), date: puzzle.date)
        }
        if let puzzle = weekly {
            let progress = UserProgress.load(puzzleId: puzzle.id)
            let completed = progress?.completedClueIds.count ?? 0
            let pct = puzzle.clues.count > 0 ? Int(Double(completed) / Double(puzzle.clues.count) * 100) : 0
            rating.upsertWeeklyCrossword(score: Int.crosswordScore(percentComplete: pct), date: puzzle.date)
        }
        backfillFromDisk()
    }

    // MARK: - Crossword Scoring

    /// Record a crossword completion score immediately (e.g. when the user finishes a puzzle in-session).
    func recordDailyCrossword(completedClues: Int, totalClues: Int, date: String) {
        let pct = totalClues > 0 ? Int(Double(completedClues) / Double(totalClues) * 100) : 0
        let score = Int.crosswordScore(percentComplete: pct)
        rating.upsertDailyCrossword(score: score, date: date)
        rating.save()
    }

    func recordWeeklyCrossword(completedClues: Int, totalClues: Int, date: String) {
        let pct = totalClues > 0 ? Int(Double(completedClues) / Double(totalClues) * 100) : 0
        let score = Int.crosswordScore(percentComplete: pct)
        rating.upsertWeeklyCrossword(score: score, date: date)
        rating.save()
    }

    // MARK: - Backword Scoring

    /// Record a Backword result. `guessCount` is nil on a loss.
    func recordBackword(guessCount: Int?, date: String) {
        let score = Int.backwordScore(guessCount: guessCount)
        rating.upsertBackword(score: score, date: date)
        rating.save()
    }
}
