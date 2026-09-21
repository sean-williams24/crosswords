import Foundation
import Testing
@testable import Backword

@Suite("Puzzle result sharing")
struct PuzzleResultShareTests {
    @Test("Backword result is spoiler-safe and links to its exact issue")
    func backwordResultIsSpoilerSafe() {
        var progress = BackwordProgress(date: "2026-09-16")
        progress.guesses = ["CASTLE"]
        progress.wonFlag = true
        progress.completedAt = Date(timeIntervalSince1970: 1_789_593_840)

        var rating = OverallRating()
        rating.upsertBackword(score: 5, date: "2026-09-16")
        var stats = BackwordStats()
        stats.gamesWon = 3
        stats.currentStreak = 3
        stats.lastCompletedDate = "2026-09-16"

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
        #expect(result.shareURL.absoluteString == "https://www.playbackword.com/backword/2026-09-16?utm_source=share&utm_medium=social&utm_campaign=completed_puzzle")
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

    @Test("Crossword result reports duration, matching streak, and weekly route")
    func crosswordResultReportsStats() {
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
        progress.completedAt = Date(timeIntervalSince1970: 1_883)

        var rating = OverallRating()
        rating.upsertWeeklyCrossword(score: 4, date: puzzle.date)
        var stats = UserStats()
        stats.history = [
            PuzzleResult(
                puzzleId: puzzle.id,
                date: Date(),
                timeSeconds: 83,
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
        #expect(result.primaryStat == PuzzleShareResult.Stat(label: "SOLVE TIME", value: "01:23"))
        #expect(result.shareURL.path == "/weekly-crossword/2026-09-14")
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

    @Test("Backword completion time includes an AM or PM marker")
    func completionTimeUsesTwelveHourClock() {
        let utc = TimeZone(secondsFromGMT: 0)!
        let completionTime = PuzzleShareResult.completedTime(
            Date(timeIntervalSince1970: 0),
            timeZone: utc
        )

        #expect(completionTime == "12:00 AM")
    }

    @Test("Backword and Pro Crossword share cards always use a dark appearance")
    func darkShareCardAppearance() {
        #expect(PuzzleShareResult.Game.weeklyCrossword.usesDarkShareCardAppearance)
        #expect(PuzzleShareResult.Game.backword.usesDarkShareCardAppearance)
        #expect(!PuzzleShareResult.Game.dailyCrossword.usesDarkShareCardAppearance)
    }

    @Test("Backword share cards use the fixed light stat-label treatment")
    func backwordShareCardStatLabels() {
        #expect(PuzzleShareResult.Game.backword.usesHighContrastShareCardStatLabels)
        #expect(!PuzzleShareResult.Game.dailyCrossword.usesHighContrastShareCardStatLabels)
        #expect(!PuzzleShareResult.Game.weeklyCrossword.usesHighContrastShareCardStatLabels)
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
