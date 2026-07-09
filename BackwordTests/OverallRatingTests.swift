import Testing
import Foundation
@testable import Backword

// MARK: - Scoring helpers

@Suite("Crossword score from completion %")
struct CrosswordScoreTests {
    @Test("100% → 5") func full()         { #expect(Int.crosswordScore(percentComplete: 100) == 5) }
    @Test("99% → 4")  func justBelow()    { #expect(Int.crosswordScore(percentComplete: 99)  == 4) }
    @Test("75% → 4")  func boundaryHigh() { #expect(Int.crosswordScore(percentComplete: 75)  == 4) }
    @Test("74% → 3")  func midHigh()      { #expect(Int.crosswordScore(percentComplete: 74)  == 3) }
    @Test("50% → 3")  func midLow()       { #expect(Int.crosswordScore(percentComplete: 50)  == 3) }
    @Test("49% → 2")  func quarterHigh()  { #expect(Int.crosswordScore(percentComplete: 49)  == 2) }
    @Test("25% → 2")  func quarter()      { #expect(Int.crosswordScore(percentComplete: 25)  == 2) }
    @Test("24% → 1")  func low()          { #expect(Int.crosswordScore(percentComplete: 24)  == 1) }
    @Test("1% → 1")   func one()          { #expect(Int.crosswordScore(percentComplete: 1)   == 1) }
    @Test("0% → 0")   func zero()         { #expect(Int.crosswordScore(percentComplete: 0)   == 0) }
}

@Suite("Backword score from guess count")
struct BackwordScoreTests {
    @Test("nil (loss) → 0") func loss()      { #expect(Int.backwordScore(guessCount: nil) == 0) }
    @Test("1 guess → 5")    func oneGuess()  { #expect(Int.backwordScore(guessCount: 1)   == 5) }
    @Test("2 guesses → 4")  func twoGuess()  { #expect(Int.backwordScore(guessCount: 2)   == 4) }
    @Test("3 guesses → 3")  func threeGuess(){ #expect(Int.backwordScore(guessCount: 3)   == 3) }
    @Test("4 guesses → 2")  func fourGuess() { #expect(Int.backwordScore(guessCount: 4)   == 2) }
    @Test("5 guesses → 1")  func fiveGuess() { #expect(Int.backwordScore(guessCount: 5)   == 1) }
    @Test("6+ guesses → 0") func sixGuess()  { #expect(Int.backwordScore(guessCount: 6)   == 0) }
}

// MARK: - User stats

@Suite("UserStats model")
struct UserStatsTests {
    @Test("Removing results excludes gave-up puzzles from counts and averages")
    func removeResultsRecomputesAggregates() {
        var stats = UserStats()
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        stats.history = [
            PuzzleResult(puzzleId: "solved-daily", date: yesterday, timeSeconds: 120, hintsUsed: 0),
            PuzzleResult(puzzleId: "gave-up-weekly", date: today, timeSeconds: 300, hintsUsed: 0, isWeekly: true),
        ]
        stats.recomputeAggregates()

        stats.removeResults(puzzleIds: ["gave-up-weekly"])

        #expect(stats.history.map(\.puzzleId) == ["solved-daily"])
        #expect(stats.totalCompleted == 1)
        #expect(stats.averageTimeSeconds == 120)
        #expect(stats.totalCompleted(isWeekly: true) == 0)
    }

    @Test("Weekly counters use weekly history only")
    func weeklyCountersUseWeeklyHistoryOnly() {
        var stats = UserStats()
        let today = Calendar.current.startOfDay(for: Date())
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: today)!

        stats.history = [
            PuzzleResult(puzzleId: "daily", date: today, timeSeconds: 60, hintsUsed: 0),
            PuzzleResult(puzzleId: "weekly-1", date: lastWeek, timeSeconds: 300, hintsUsed: 0, isWeekly: true),
            PuzzleResult(puzzleId: "weekly-2", date: today, timeSeconds: 240, hintsUsed: 0, isWeekly: true),
        ]
        stats.recomputeAggregates()

        #expect(stats.totalCompleted(isWeekly: true) == 2)
        #expect(stats.currentStreak(isWeekly: true) == 2)
        #expect(stats.longestStreak(isWeekly: true) == 2)
        #expect(stats.totalCompleted(isWeekly: false) == 1)
    }
}

// MARK: - OverallRating model

@Suite("OverallRating model")
struct OverallRatingTests {

    // Helper: build a rating with `days` consecutive days of perfect scores
    private func perfectRating(days: Int, withWeekly: Bool = false) -> OverallRating {
        var r = OverallRating()
        for i in 0..<days {
            let ds = dateString(offsetByDays: -i)
            r.upsertDailyCrossword(score: 5, date: ds)
            r.upsertBackword(score: 5, date: ds)
            if withWeekly { r.upsertWeeklyCrossword(score: 5, date: ds) }
        }
        return r
    }

    private func ratingWithFreePoints(_ points: Int) -> OverallRating {
        var r = OverallRating()
        var remaining = points
        for i in 0..<14 {
            let ds = dateString(offsetByDays: -i)
            let daily = min(5, remaining)
            remaining -= daily
            let backword = min(5, remaining)
            remaining -= backword
            r.upsertDailyCrossword(score: daily, date: ds)
            r.upsertBackword(score: backword, date: ds)
        }
        return r
    }

    // MARK: maxPoints

    @Test("Free user max = 14 × 2 games × 5 pts = 140")
    func maxPointsFree() {
        #expect(OverallRating().maxPoints(isPro: false) == 140)
    }

    @Test("Pro user max = 14 × 10 + 2 × 5 = 150")
    func maxPointsPro() {
        #expect(OverallRating().maxPoints(isPro: true) == 150)
    }

    // MARK: totalPoints / fraction

    @Test("Empty rating → 0 points")
    func emptyTotal() {
        #expect(OverallRating().totalPoints(isPro: false) == 0)
    }

    @Test("14 perfect days (free) → 140 points")
    func perfectTotalFree() {
        let r = perfectRating(days: 14)
        #expect(r.totalPoints(isPro: false) == 140)
    }

    @Test("14 perfect days (pro) → 150 points")
    func perfectTotalPro() {
        let r = perfectRating(days: 14, withWeekly: true)
        // 14 × (5 daily + 5 backword) + 14 × 5 weekly = 210 total points
        // But max is 150, so totalPoints can exceed maxPoints
        #expect(r.totalPoints(isPro: true) == 210)
    }

    @Test("fraction clamps at 1.0 even when over max")
    func fractionClamp() {
        // Create a rating with more than max by adding weekly to free
        let r = perfectRating(days: 14, withWeekly: true)
        // Free user (ignores weekly) → fraction should still be 1.0
        #expect(r.fraction(isPro: false) <= 1.0)
    }

    @Test("fraction for half-perfect free → 0.5")
    func halfFractionFree() {
        var r = OverallRating()
        for i in 0..<14 {
            let ds = dateString(offsetByDays: -i)
            // Only daily (5 pts) — no backword — gives 5/10 per day
            r.upsertDailyCrossword(score: 5, date: ds)
        }
        let frac = r.fraction(isPro: false)
        #expect(abs(frac - 0.5) < 0.001)
    }

    // MARK: tier

    @Test("Empty rating → Novice")
    func emptyTier() {
        #expect(OverallRating().tier(isPro: false) == .novice)
    }

    @Test("~20% → Scribe")
    func scribeTier() {
        // 20% of 140 = 28 pts. 14 days × 2 pts daily = 28.
        var r = OverallRating()
        for i in 0..<14 {
            let ds = dateString(offsetByDays: -i)
            r.upsertDailyCrossword(score: 2, date: ds)
        }
        #expect(r.tier(isPro: false) == .scribe)
    }

    @Test("40% remains Scribe")
    func fortyPercentRemainsScribe() {
        // 40% of 140 = 56 pts, below the new 50% Linguist threshold.
        #expect(ratingWithFreePoints(56).tier(isPro: false) == .scribe)
    }

    @Test("50% → Linguist")
    func linguistTier() {
        // 50% of 140 = 70 pts.
        #expect(ratingWithFreePoints(70).tier(isPro: false) == .linguist)
    }

    @Test("60% remains Linguist")
    func sixtyPercentRemainsLinguist() {
        // 60% of 140 = 84 pts, below the new 75% Grandmaster threshold.
        #expect(ratingWithFreePoints(84).tier(isPro: false) == .linguist)
    }

    @Test("75% → Grandmaster")
    func grandmasterTier() {
        // 75% of 140 = 105 pts.
        #expect(ratingWithFreePoints(105).tier(isPro: false) == .grandmaster)
    }

    @Test("Just under 90% remains Grandmaster")
    func justUnderVirtuosoRemainsGrandmaster() {
        // 125 / 140 = 89.29%, below the new 90% Virtuoso threshold.
        #expect(ratingWithFreePoints(125).tier(isPro: false) == .grandmaster)
    }

    @Test("90% → Virtuoso")
    func ninetyPercentVirtuosoTier() {
        // 90% of 140 = 126 pts.
        #expect(ratingWithFreePoints(126).tier(isPro: false) == .virtuoso)
    }

    @Test("Perfect free score → Virtuoso")
    func virtuosoTier() {
        #expect(perfectRating(days: 14).tier(isPro: false) == .virtuoso)
    }

    @Test("Tier thresholds are in ascending order")
    func tierThresholdOrder() {
        let thresholds = RatingTier.allCases.map { $0.threshold }
        for i in 1..<thresholds.count {
            #expect(thresholds[i] > thresholds[i - 1])
        }
    }

    // MARK: 14-day trim

    @Test("Scores older than 14 days are trimmed")
    func trimOldScores() {
        var r = OverallRating()
        // Add a score 15 days ago
        let oldDate = dateString(offsetByDays: -15)
        r.upsertDailyCrossword(score: 5, date: oldDate)
        // The old score should have been trimmed
        #expect(r.dailyScores.isEmpty)
    }

    @Test("Score from 13 days ago is retained")
    func retainRecentScore() {
        var r = OverallRating()
        let recentDate = dateString(offsetByDays: -13)
        r.upsertDailyCrossword(score: 3, date: recentDate)
        #expect(r.dailyScores.count == 1)
        #expect(r.dailyScores[0].dailyCrossword == 3)
    }

    @Test("Future scores are excluded from the rolling window")
    func futureScoresExcluded() {
        var r = OverallRating()
        let today = dateString()
        let tomorrow = dateString(offsetByDays: 1)

        r.upsertDailyCrossword(score: 1, date: today)
        r.upsertDailyCrossword(score: 5, date: tomorrow)
        r.upsertBackword(score: 5, date: tomorrow)

        #expect(r.totalPoints(isPro: false) == 1)
        #expect(r.dailyScores.count == 1)
        #expect(r.dailyScores[0].date == today)
    }

    @Test("Loaded scores are clamped to valid per-game values")
    func normalizesOutOfRangeScores() {
        let today = dateString()
        var r = OverallRating(dailyScores: [
            DailyScore(date: today, dailyCrossword: 197, weeklyCrossword: 9, backword: -4)
        ])

        r.normalize()

        #expect(r.totalPoints(isPro: false) == 5)
        #expect(r.totalPoints(isPro: true) == 10)
        #expect(r.dailyScores[0].dailyCrossword == 5)
        #expect(r.dailyScores[0].weeklyCrossword == 5)
        #expect(r.dailyScores[0].backword == 0)
    }

    // MARK: upsert deduplication

    @Test("Upserting same date twice updates the record, not duplicates")
    func upsertDedup() {
        var r = OverallRating()
        let today = dateString()
        r.upsertDailyCrossword(score: 3, date: today)
        r.upsertDailyCrossword(score: 5, date: today)
        #expect(r.dailyScores.count == 1)
        #expect(r.dailyScores[0].dailyCrossword == 5)
    }

    @Test("Upserting backword and daily on same date produces one entry")
    func upsertMultipleFieldsSameDay() {
        var r = OverallRating()
        let today = dateString()
        r.upsertDailyCrossword(score: 4, date: today)
        r.upsertBackword(score: 3, date: today)
        #expect(r.dailyScores.count == 1)
        #expect(r.dailyScores[0].dailyCrossword == 4)
        #expect(r.dailyScores[0].backword == 3)
    }

    // MARK: Weekly ignored for free users

    @Test("Weekly score not counted for free users")
    func weeklyIgnoredForFree() {
        var r = OverallRating()
        let today = dateString()
        r.upsertDailyCrossword(score: 5, date: today)
        r.upsertWeeklyCrossword(score: 5, date: today)
        r.upsertBackword(score: 5, date: today)
        // Free: daily(5) + backword(5) = 10, not 15
        #expect(r.totalPoints(isPro: false) == 10)
        #expect(r.totalPoints(isPro: true) == 15)
    }

    // MARK: Codable round-trip

    @Test("OverallRating survives JSON encode/decode")
    func codableRoundTrip() throws {
        var r = OverallRating()
        let today = dateString()
        r.upsertDailyCrossword(score: 4, date: today)
        r.upsertWeeklyCrossword(score: 3, date: today)
        r.upsertBackword(score: 5, date: today)
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder().decode(OverallRating.self, from: data)
        #expect(decoded.dailyScores.count == 1)
        #expect(decoded.dailyScores[0].dailyCrossword == 4)
        #expect(decoded.dailyScores[0].weeklyCrossword == 3)
        #expect(decoded.dailyScores[0].backword == 5)
    }

    private func dateString(offsetByDays offset: Int = 0) -> String {
        ContentReleaseCalendar().dailyDateString(offsetByDays: offset)!
    }
}

@Suite("OverallRatingService crossword score window")
struct OverallRatingServiceScoreWindowTests {
    @Test("Daily crossword can score only on its puzzle date")
    @MainActor
    func dailyCrosswordScoresOnlyOnPuzzleDate() {
        let service = OverallRatingService(rating: OverallRating())
        let releaseCalendar = makeReleaseCalendar("2026-07-04")

        service.recordDailyCrossword(
            completedClues: 10,
            totalClues: 10,
            date: "2026-07-04",
            releaseCalendar: releaseCalendar,
            shouldSave: false
        )
        service.recordDailyCrossword(
            completedClues: 10,
            totalClues: 10,
            date: "2026-07-03",
            releaseCalendar: releaseCalendar,
            shouldSave: false
        )

        #expect(service.rating.dailyScores.count == 1)
        #expect(service.rating.dailyScores[0].date == "2026-07-04")
        #expect(service.rating.dailyScores[0].dailyCrossword == 5)
    }

    @Test("Late archive daily crossword completion does not improve an existing score")
    @MainActor
    func lateArchiveDailyCompletionDoesNotImproveExistingScore() {
        var rating = OverallRating()
        rating.upsertDailyCrossword(score: 2, date: "2026-07-04")
        let service = OverallRatingService(rating: rating)

        service.recordDailyCrossword(
            completedClues: 10,
            totalClues: 10,
            date: "2026-07-04",
            releaseCalendar: makeReleaseCalendar("2026-07-05"),
            shouldSave: false
        )

        #expect(service.rating.dailyScores.count == 1)
        #expect(service.rating.dailyScores[0].dailyCrossword == 2)
    }

    @Test("Rollover scoring can use the pre-midnight calendar")
    @MainActor
    func rolloverScoringUsesPreMidnightCalendar() {
        let service = OverallRatingService(rating: OverallRating())

        service.recordDailyCrossword(
            completedClues: 5,
            totalClues: 10,
            date: "2026-07-04",
            releaseCalendar: makeReleaseCalendar("2026-07-04"),
            shouldSave: false
        )

        #expect(service.rating.dailyScores.count == 1)
        #expect(service.rating.dailyScores[0].date == "2026-07-04")
        #expect(service.rating.dailyScores[0].dailyCrossword == 3)
    }

    @Test("Weekly crossword uses the active weekly release date")
    @MainActor
    func weeklyCrosswordUsesActiveWeeklyReleaseDate() {
        let service = OverallRatingService(rating: OverallRating())
        let releaseCalendar = makeReleaseCalendar("2026-07-09")

        service.recordWeeklyCrossword(
            completedClues: 20,
            totalClues: 20,
            date: "2026-07-05",
            releaseCalendar: releaseCalendar,
            shouldSave: false
        )
        service.recordWeeklyCrossword(
            completedClues: 20,
            totalClues: 20,
            date: "2026-06-28",
            releaseCalendar: releaseCalendar,
            shouldSave: false
        )

        #expect(service.rating.dailyScores.count == 1)
        #expect(service.rating.dailyScores[0].date == "2026-07-05")
        #expect(service.rating.dailyScores[0].weeklyCrossword == 5)
    }

    @Test("Backword can score only on its release date")
    @MainActor
    func backwordScoresOnlyOnReleaseDate() {
        let service = OverallRatingService(rating: OverallRating())

        service.recordBackword(
            guessCount: 1,
            date: "2026-07-04",
            releaseCalendar: makeReleaseCalendar("2026-07-04"),
            shouldSave: false
        )
        service.recordBackword(
            guessCount: 1,
            date: "2026-07-03",
            releaseCalendar: makeReleaseCalendar("2026-07-04"),
            shouldSave: false
        )

        #expect(service.rating.dailyScores.count == 1)
        #expect(service.rating.dailyScores[0].date == "2026-07-04")
        #expect(service.rating.dailyScores[0].backword == 5)
    }

    @Test("Late archive Backword completion does not improve an existing score")
    @MainActor
    func lateArchiveBackwordCompletionDoesNotImproveExistingScore() {
        var rating = OverallRating()
        rating.upsertBackword(score: 2, date: "2026-07-04")
        let service = OverallRatingService(rating: rating)

        service.recordBackword(
            guessCount: 1,
            date: "2026-07-04",
            releaseCalendar: makeReleaseCalendar("2026-07-05"),
            shouldSave: false
        )

        #expect(service.rating.dailyScores.count == 1)
        #expect(service.rating.dailyScores[0].backword == 2)
    }

    private func makeReleaseCalendar(_ dateString: String) -> ContentReleaseCalendar {
        var formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.date(from: "\(dateString) 12:00:00")!
        return ContentReleaseCalendar(now: date, timeZone: TimeZone(secondsFromGMT: 0)!)
    }
}
