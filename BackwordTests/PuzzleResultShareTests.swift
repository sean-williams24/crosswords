import Foundation
import Testing
@testable import Backword

@Suite("Puzzle result sharing")
struct PuzzleResultShareTests {
    @Test("Backword result is spoiler-safe and links to its exact issue")
    func backwordResultIsSpoilerSafe() {
        let today = ContentReleaseCalendar().dailyDateString
        var progress = BackwordProgress(date: today)
        progress.guesses = ["CASTLE"]
        progress.wonFlag = true
        progress.completedAt = Date(timeIntervalSince1970: 1_789_593_840)

        var rating = OverallRating()
        rating.upsertBackword(score: 5, date: today)
        var stats = BackwordStats()
        stats.gamesWon = 3
        stats.currentStreak = 3
        stats.lastCompletedDate = today

        let word = BackwordWord(
            id: "word-id",
            date: progress.date,
            puzzleNumber: 170,
            word: "CASTLE",
            clue: "A fortress"
        )
        let result = PuzzleShareResult.backword(
            progress: progress,
            word: word,
            stats: stats,
            rating: rating,
            isPro: false
        )

        #expect(result.issueLabel == "Backword #170")
        #expect(result.score == 5)
        #expect(result.scoreLabel == "5 pts")
        #expect(result.streak == 3)
        #expect(result.totalGamesSolved == 3)
        #expect(result.primaryStat == .init(label: "ATTEMPTS", value: "1/5"))
        #expect(result.shareURL.absoluteString == "https://www.playbackword.com/backword/\(today)?utm_source=share&utm_medium=social&utm_campaign=completed_puzzle")
        #expect(result.caption.contains("CASTLE") == false)
        #expect(result.caption.contains("fortress") == false)
        #expect(result.caption.contains("word-id") == false)
    }

    @Test("Failed Backword result is neutral and earns no points")
    func failedBackwordResultIsNeutral() {
        var progress = BackwordProgress(date: "2026-09-16")
        progress.guesses = ["PLANET", "GARDEN", "ORANGE", "STREAM", "CASTLE"]
        progress.completedAt = Date(timeIntervalSince1970: 1_789_593_840)

        let result = PuzzleShareResult.backword(
            progress: progress,
            word: BackwordWord(id: "word-id", date: progress.date, puzzleNumber: 170, word: "CASTLE", clue: "A fortress"),
            stats: BackwordStats(),
            rating: OverallRating(),
            isPro: false
        )

        #expect(result.outcome == "COMPLETED")
        #expect(result.score == 0)
        #expect(result.caption.contains("CASTLE") == false)
        #expect(result.caption.contains("PLANET") == false)
    }

    @Test("Crossword result reports duration, matching streak, and weekly route",
          arguments: [(83, "00:01:23"), (4_845, "01:20:45")])
    func crosswordResultReportsStats(seconds: Int, expectedTime: String) {
        let puzzle = Puzzle(
            id: "weekly-id",
            puzzleNumber: 42,
            date: "2026-09-14",
            size: 13,
            cells: [],
            clues: []
        )
        var progress = UserProgress(puzzleId: puzzle.id, size: puzzle.size)
        progress.startedAt = Date(timeIntervalSince1970: 1_800)
        progress.completedAt = Date(timeIntervalSince1970: TimeInterval(1_800 + seconds))

        var rating = OverallRating()
        rating.upsertWeeklyCrossword(score: 4, date: puzzle.date)
        var stats = UserStats()
        stats.history = [
            PuzzleResult(
                puzzleId: puzzle.id,
                date: Date(),
                timeSeconds: seconds,
                hintsUsed: 0,
                isWeekly: true
            )
        ]

        let result = PuzzleShareResult.crossword(
            puzzle: puzzle,
            progress: progress,
            stats: stats,
            rating: rating,
            isPro: true
        )

        #expect(result.game == PuzzleShareResult.Game.weeklyCrossword)
        #expect(result.score == 4)
        #expect(result.totalGamesSolved == 1)
        #expect(result.primaryStat == PuzzleShareResult.Stat(label: "SOLVE TIME", value: expectedTime))
        #expect(result.caption.contains(expectedTime))
        #expect(result.shareURL.path == "/weekly-crossword/2026-09-14")
    }

    @Test("Anagram result reports its score, duration and stays spoiler-safe",
          arguments: [(45, "00:00:45"), (4_845, "01:20:45"), (90_061, "25:01:01")])
    func anagramResultReportsStats(seconds: Int, expectedTime: String) {
        let date = AnagramProgress.localDay(Date())
        let puzzle = AnagramPuzzle(
            id: "anagram-id", date: date, puzzleNumber: 8, schemaVersion: 1,
            answer: "TRIANGLE", acceptedAnswers: [], initialScramble: "RAGTLINE"
        )
        var progress = AnagramProgress(puzzle: puzzle)
        progress.outcome = .solved
        progress.completedAt = Date()
        progress.elapsedSecondsAtCompletion = seconds
        progress.releaseDateScore = 4
        let history = AnagramStatsHistory(
            rows: [], currentStreak: 2, bestStreak: 3,
            totalSolved: 6, averageSolveTime: "0:45"
        )
        var rating = OverallRating()
        rating.upsertAnagram(score: 4, date: date)

        let result = PuzzleShareResult.anagram(
            completion: AnagramCompletion(puzzle: puzzle, progress: progress),
            history: history,
            rating: rating,
            isPro: false
        )

        #expect(result.game == .anagram)
        #expect(result.issueLabel == "Anagram #8")
        #expect(result.score == 4)
        #expect(result.streak == 2)
        #expect(result.totalGamesSolved == 6)
        #expect(result.primaryStat == PuzzleShareResult.Stat(label: "SOLVE TIME", value: expectedTime))
        #expect(result.caption.contains(expectedTime))
        #expect(result.shareURL.path == "/anagram/\(date)")
        #expect(result.caption.contains("TRIANGLE") == false)
        #expect(result.caption.contains("RAGTLINE") == false)
    }

    @Test("Midword result reports guesses without revealing its compounds")
    func midwordResultReportsStats() {
        let puzzle = MidwordPuzzle(
            id: "midword-id", date: "2026-10-05", puzzleNumber: 5,
            firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: []
        )
        var progress = MidwordProgress(date: puzzle.date)
        progress.guesses = ["PAGE", "NOTE"]
        progress.completedAt = Date()
        progress.won = true
        progress.releaseDateScore = 4
        let history = MidwordStatsHistory(
            rows: [], currentStreak: 2, bestStreak: 3,
            totalSolved: 4, guessDistribution: [2: 1]
        )

        let result = PuzzleShareResult.midword(
            puzzle: puzzle,
            progress: progress,
            history: history,
            rating: OverallRating(),
            isPro: false
        )

        #expect(result.game == .midword)
        #expect(result.issueLabel == "Midword #5")
        #expect(result.score == 4)
        #expect(result.primaryStat == PuzzleShareResult.Stat(label: "GUESSES", value: "2/5"))
        #expect(result.shareURL.path == "/midword/2026-10-05")
        #expect(result.caption.contains("NOTE") == false)
        #expect(result.caption.contains("BANK") == false)
        #expect(result.caption.contains("BOOK") == false)
    }

    @Test("A one-point result uses the singular score label")
    func singularScoreLabel() {
        let result = PuzzleShareResult(
            game: .backword,
            issueNumber: 173,
            date: "2026-09-20",
            outcome: "SOLVED",
            score: 1,
            streak: 1,
            totalGamesSolved: 1,
            ratingTier: "Novice",
            ratingPoints: 1,
            ratingMaxPoints: 140,
            primaryStat: .init(label: "ATTEMPTS", value: "5 / 5"),
            timeStat: nil
        )

        #expect(result.scoreLabel == "1 pt")
    }

    @Test("Share durations always include hours, minutes and seconds",
          arguments: [(-1, "00:00:00"), (0, "00:00:00"), (59, "00:00:59"), (60, "00:01:00"),
                      (3_599, "00:59:59"), (3_600, "01:00:00"), (4_845, "01:20:45"),
                      (86_400, "24:00:00"), (360_000, "100:00:00")])
    func fixedShareDuration(seconds: Int, expected: String) {
        #expect(PuzzleShareResult.formattedDuration(seconds) == expected)
    }

    @Test("Backword completion time uses a local 24-hour clock with seconds")
    func completionTimeIncludesSeconds() {
        let utc = TimeZone(secondsFromGMT: 0)!
        let completionTime = PuzzleShareResult.completedTime(
            Date(timeIntervalSince1970: 0),
            timeZone: utc
        )

        #expect(completionTime == "00:00:00")
        #expect(PuzzleShareResult.completedTime(Date(timeIntervalSince1970: 52_245), timeZone: utc) == "14:30:45")
        #expect(PuzzleShareResult.completedTime(
            Date(timeIntervalSince1970: 0), timeZone: TimeZone(secondsFromGMT: 3_600)!
        ) == "01:00:00")
        #expect(PuzzleShareResult.completedTime(nil, timeZone: utc) == "—")
    }

    @Test("Dark game share cards always use a dark appearance")
    func darkShareCardAppearance() {
        #expect(PuzzleShareResult.Game.weeklyCrossword.usesDarkShareCardAppearance)
        #expect(PuzzleShareResult.Game.backword.usesDarkShareCardAppearance)
        #expect(PuzzleShareResult.Game.anagram.usesDarkShareCardAppearance)
        #expect(PuzzleShareResult.Game.midword.usesDarkShareCardAppearance)
        #expect(!PuzzleShareResult.Game.dailyCrossword.usesDarkShareCardAppearance)
    }

    @Test("Backword share cards use the fixed light stat-label treatment")
    func backwordShareCardStatLabels() {
        #expect(PuzzleShareResult.Game.backword.usesHighContrastShareCardStatLabels)
        #expect(!PuzzleShareResult.Game.dailyCrossword.usesHighContrastShareCardStatLabels)
        #expect(!PuzzleShareResult.Game.weeklyCrossword.usesHighContrastShareCardStatLabels)
    }

    @Test("Backword share card uses the Dark Mode home-card background")
    func backwordShareCardBackground() {
        #expect(PuzzleShareResult.Game.backword.usesHomeCardBackwordBackground)
        #expect(!PuzzleShareResult.Game.dailyCrossword.usesHomeCardBackwordBackground)
        #expect(!PuzzleShareResult.Game.weeklyCrossword.usesHomeCardBackwordBackground)
    }

    @Test("Share cards use compact geometry with a high-definition export")
    func shareCardLayout() {
        #expect(PuzzleResultShareCardLayout.canvasSize == 540)
        #expect(PuzzleResultShareCardLayout.exportPixelSize == 1080)
        #expect(PuzzleResultShareCardLayout.renderScale == 2)
        #expect(PuzzleResultShareCardLayout.cornerRadius == 24)
        #expect(PuzzleResultShareCardLayout.statWidth == 226)
    }

    @Test("Returning from an external share destination releases the share sheet")
    func externalShareReturnDismissesShareSheet() {
        #expect(
            PuzzleResultShareSheetLifecycle.shouldDismissShareSheet(
                isPresented: true,
                wasBackgrounded: true,
                becameActive: true
            )
        )
        #expect(
            !PuzzleResultShareSheetLifecycle.shouldDismissShareSheet(
                isPresented: true,
                wasBackgrounded: false,
                becameActive: true
            )
        )
        #expect(
            !PuzzleResultShareSheetLifecycle.shouldDismissShareSheet(
                isPresented: false,
                wasBackgrounded: true,
                becameActive: true
            )
        )
    }
}
