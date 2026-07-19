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
        let releaseCalendar = ContentReleaseCalendar()
        let cutoff = releaseCalendar.dailyDateString(offsetByDays: -13) ?? DateFormatting().todayString()
        let progressRecords = UserProgress.loadAll()

        // Backword
        for bw in BackwordProgress.loadAll() where bw.date >= cutoff {
            guard bw.isComplete else { continue }
            guard Self.canScoreBackword(progress: bw) else { continue }
            let score = bw.isWon ? Int.backwordScore(guessCount: bw.guesses.count) : 0
            rating.upsertBackword(score: score, date: bw.date)
        }

        // Crosswords — scan all progress files that have metadata
        for p in progressRecords {
            guard p.gaveUpAt == nil,
                  let date = p.puzzleDate, date >= cutoff,
                  let total = p.totalClues, total > 0 else { continue }
            let scoringCalendar = p.completedAt.map { ContentReleaseCalendar(now: $0) } ?? releaseCalendar
            guard Self.canScoreCrossword(date: date, isWeekly: p.isWeekly == true, releaseCalendar: scoringCalendar) else {
                continue
            }
            let completed = p.completedClueIds.count
            let pct = Int(Double(completed) / Double(total) * 100)
            let score = max(0, Int.crosswordScore(percentComplete: pct) - p.hintsUsed / 3)
            if p.isWeekly == true {
                rating.upsertWeeklyCrossword(score: score, date: date)
            } else {
                rating.upsertDailyCrossword(score: score, date: date)
            }
        }

        removeInvalidPerfectCrosswordScores(using: progressRecords)
        removeInvalidBackwordScores()
        rating.save()
    }

    private func removeInvalidPerfectCrosswordScores(using progressRecords: [UserProgress]) {
        let onTimeDailySolvedDates = Set(progressRecords.compactMap { progress -> String? in
            guard progress.isWeekly != true,
                  progress.gaveUpAt == nil,
                  let puzzleDate = progress.puzzleDate,
                  let completedAt = progress.completedAt,
                  ContentReleaseCalendar(now: completedAt).dailyDateString == puzzleDate else { return nil }
            return puzzleDate
        })
        let onTimeWeeklySolvedDates = Set(progressRecords.compactMap { progress -> String? in
            guard progress.isWeekly == true,
                  progress.gaveUpAt == nil,
                  let puzzleDate = progress.puzzleDate,
                  let completedAt = progress.completedAt,
                  ContentReleaseCalendar(now: completedAt).weeklyDateString == puzzleDate else { return nil }
            return puzzleDate
        })

        for idx in rating.dailyScores.indices {
            let date = rating.dailyScores[idx].date
            if rating.dailyScores[idx].dailyCrossword == 5,
               !onTimeDailySolvedDates.contains(date) {
                rating.dailyScores[idx].dailyCrossword = 0
            }
            if rating.dailyScores[idx].weeklyCrossword == 5,
               !onTimeWeeklySolvedDates.contains(date) {
                rating.dailyScores[idx].weeklyCrossword = 0
            }
        }
        rating.trim()
    }

    private func removeInvalidBackwordScores() {
        let onTimeWonDates = Set(BackwordProgress.loadAll().compactMap { progress -> String? in
            guard Self.canScoreBackword(progress: progress),
                  progress.isWon else { return nil }
            return progress.date
        })

        for idx in rating.dailyScores.indices {
            let date = rating.dailyScores[idx].date
            if rating.dailyScores[idx].backword > 0,
               !onTimeWonDates.contains(date) {
                rating.dailyScores[idx].backword = 0
            }
        }
        rating.trim()
    }

    /// Records progress for the currently loaded daily and/or weekly puzzle,
    /// then backfills all historical scores from disk.
    func recordCurrentPuzzles(
        daily: Puzzle?,
        weekly: Puzzle?,
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar()
    ) {
        if let puzzle = daily {
            let progress = UserProgress.load(puzzleId: puzzle.id)
            let completed = progress?.completedClueIds.count ?? 0
            let hintsUsed = progress?.hintsUsed ?? 0
            recordDailyCrossword(
                completedClues: completed,
                totalClues: puzzle.clues.count,
                date: puzzle.date,
                hintsUsed: hintsUsed,
                releaseCalendar: releaseCalendar,
                shouldSave: false
            )
        }
        if let puzzle = weekly {
            let progress = UserProgress.load(puzzleId: puzzle.id)
            let completed = progress?.completedClueIds.count ?? 0
            let hintsUsed = progress?.hintsUsed ?? 0
            recordWeeklyCrossword(
                completedClues: completed,
                totalClues: puzzle.clues.count,
                date: puzzle.date,
                hintsUsed: hintsUsed,
                releaseCalendar: releaseCalendar,
                shouldSave: false
            )
        }
        backfillFromDisk()
    }

    // MARK: - Crossword Scoring

    /// Record a crossword completion score immediately (e.g. when the user finishes a puzzle in-session).
    func recordDailyCrossword(
        completedClues: Int,
        totalClues: Int,
        date: String,
        hintsUsed: Int = 0,
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar(),
        shouldSave: Bool = true
    ) {
        guard Self.canScoreDailyCrossword(date: date, releaseCalendar: releaseCalendar) else { return }
        let pct = totalClues > 0 ? Int(Double(completedClues) / Double(totalClues) * 100) : 0
        let score = max(0, Int.crosswordScore(percentComplete: pct) - hintsUsed / 3)
        rating.upsertDailyCrossword(score: score, date: date)
        if shouldSave { rating.save() }
    }

    func recordWeeklyCrossword(
        completedClues: Int,
        totalClues: Int,
        date: String,
        hintsUsed: Int = 0,
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar(),
        shouldSave: Bool = true
    ) {
        guard Self.canScoreWeeklyCrossword(date: date, releaseCalendar: releaseCalendar) else { return }
        let pct = totalClues > 0 ? Int(Double(completedClues) / Double(totalClues) * 100) : 0
        let score = max(0, Int.crosswordScore(percentComplete: pct) - hintsUsed / 3)
        rating.upsertWeeklyCrossword(score: score, date: date)
        if shouldSave { rating.save() }
    }

    static func canScoreCrossword(
        date: String,
        isWeekly: Bool,
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar()
    ) -> Bool {
        isWeekly
            ? canScoreWeeklyCrossword(date: date, releaseCalendar: releaseCalendar)
            : canScoreDailyCrossword(date: date, releaseCalendar: releaseCalendar)
    }

    static func canScoreDailyCrossword(
        date: String,
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar()
    ) -> Bool {
        date == releaseCalendar.dailyDateString
    }

    static func canScoreWeeklyCrossword(
        date: String,
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar()
    ) -> Bool {
        date == releaseCalendar.weeklyDateString
    }

    // MARK: - Backword Scoring

    /// Record a Backword result. `guessCount` is nil on a loss.
    func recordBackword(
        guessCount: Int?,
        date: String,
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar(),
        shouldSave: Bool = true
    ) {
        guard Self.canScoreBackword(date: date, releaseCalendar: releaseCalendar) else { return }
        let score = Int.backwordScore(guessCount: guessCount)
        rating.upsertBackword(score: score, date: date)
        if shouldSave { rating.save() }
    }

    static func canScoreBackword(
        date: String,
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar()
    ) -> Bool {
        date == releaseCalendar.dailyDateString
    }

    static func canScoreBackword(progress: BackwordProgress) -> Bool {
        progress.isComplete && progress.wasCompletedOnReleaseDate
    }
}
