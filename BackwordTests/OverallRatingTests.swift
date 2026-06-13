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

// MARK: - OverallRating model

@Suite("OverallRating model")
struct OverallRatingTests {

    // Helper: build a rating with `days` consecutive days of perfect scores
    private func perfectRating(days: Int, withWeekly: Bool = false) -> OverallRating {
        var r = OverallRating()
        for i in 0..<days {
            let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let ds = OverallRating.dateFormatter.string(from: d)
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
            let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let ds = OverallRating.dateFormatter.string(from: d)
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
        var r = perfectRating(days: 14, withWeekly: true)
        // Free user (ignores weekly) → fraction should still be 1.0
        #expect(r.fraction(isPro: false) <= 1.0)
    }

    @Test("fraction for half-perfect free → 0.5")
    func halfFractionFree() {
        var r = OverallRating()
        for i in 0..<14 {
            let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let ds = OverallRating.dateFormatter.string(from: d)
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
            let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let ds = OverallRating.dateFormatter.string(from: d)
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
        let old = Calendar.current.date(byAdding: .day, value: -15, to: Date())!
        let oldDate = OverallRating.dateFormatter.string(from: old)
        r.upsertDailyCrossword(score: 5, date: oldDate)
        // The old score should have been trimmed
        #expect(r.dailyScores.isEmpty)
    }

    @Test("Score from 13 days ago is retained")
    func retainRecentScore() {
        var r = OverallRating()
        let recent = Calendar.current.date(byAdding: .day, value: -13, to: Date())!
        let recentDate = OverallRating.dateFormatter.string(from: recent)
        r.upsertDailyCrossword(score: 3, date: recentDate)
        #expect(r.dailyScores.count == 1)
        #expect(r.dailyScores[0].dailyCrossword == 3)
    }

    // MARK: upsert deduplication

    @Test("Upserting same date twice updates the record, not duplicates")
    func upsertDedup() {
        var r = OverallRating()
        let today = OverallRating.dateFormatter.string(from: Date())
        r.upsertDailyCrossword(score: 3, date: today)
        r.upsertDailyCrossword(score: 5, date: today)
        #expect(r.dailyScores.count == 1)
        #expect(r.dailyScores[0].dailyCrossword == 5)
    }

    @Test("Upserting backword and daily on same date produces one entry")
    func upsertMultipleFieldsSameDay() {
        var r = OverallRating()
        let today = OverallRating.dateFormatter.string(from: Date())
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
        let today = OverallRating.dateFormatter.string(from: Date())
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
        let today = OverallRating.dateFormatter.string(from: Date())
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
}
