import Foundation

@MainActor
final class OverallRatingService: ObservableObject {
    @Published private(set) var rating: OverallRating = .load()

    // MARK: - Init

    init() {}

    /// Preview / test initialiser — bypasses disk loading.
    init(rating: OverallRating) {
        _rating = Published(wrappedValue: rating)
    }

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
            let score = max(0, Int.crosswordScore(percentComplete: pct) - p.hintsUsed / 3)
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
            let hintsUsed = progress?.hintsUsed ?? 0
            let pct = puzzle.clues.count > 0 ? Int(Double(completed) / Double(puzzle.clues.count) * 100) : 0
            let score = max(0, Int.crosswordScore(percentComplete: pct) - hintsUsed / 3)
            rating.upsertDailyCrossword(score: score, date: puzzle.date)
        }
        if let puzzle = weekly {
            let progress = UserProgress.load(puzzleId: puzzle.id)
            let completed = progress?.completedClueIds.count ?? 0
            let hintsUsed = progress?.hintsUsed ?? 0
            let pct = puzzle.clues.count > 0 ? Int(Double(completed) / Double(puzzle.clues.count) * 100) : 0
            let score = max(0, Int.crosswordScore(percentComplete: pct) - hintsUsed / 3)
            rating.upsertWeeklyCrossword(score: score, date: puzzle.date)
        }
        backfillFromDisk()
    }

    // MARK: - Crossword Scoring

    /// Record a crossword completion score immediately (e.g. when the user finishes a puzzle in-session).
    func recordDailyCrossword(completedClues: Int, totalClues: Int, date: String, hintsUsed: Int = 0) {
        let pct = totalClues > 0 ? Int(Double(completedClues) / Double(totalClues) * 100) : 0
        let score = max(0, Int.crosswordScore(percentComplete: pct) - hintsUsed / 3)
        rating.upsertDailyCrossword(score: score, date: date)
        rating.save()
    }

    func recordWeeklyCrossword(completedClues: Int, totalClues: Int, date: String, hintsUsed: Int = 0) {
        let pct = totalClues > 0 ? Int(Double(completedClues) / Double(totalClues) * 100) : 0
        let score = max(0, Int.crosswordScore(percentComplete: pct) - hintsUsed / 3)
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
