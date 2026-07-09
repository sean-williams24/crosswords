import Foundation
import Testing
@testable import Backword

@Suite("Home tab bar")
struct HomeTabBarViewTests {
    @Test("Archive item uses unlocked content for Pro users")
    func archiveItemForProUsers() {
        let content = HomeTabBarItemContent.archive(isProUser: true)

        #expect(content.title == "Archive")
        #expect(content.systemImage == "archivebox")
        #expect(content.accessibilityLabel == "Archive")
    }

    @Test("Archive item communicates Pro requirement for free users")
    func archiveItemForFreeUsers() {
        let content = HomeTabBarItemContent.archive(isProUser: false)

        #expect(content.title == "Archive")
        #expect(content.systemImage == "lock.fill")
        #expect(content.accessibilityLabel == "Archive, Go Pro required")
    }

    @Test("Stats item content is stable")
    func statsItem() {
        #expect(HomeTabBarItemContent.stats.title == "Stats")
        #expect(HomeTabBarItemContent.stats.systemImage == "brain.head.profile")
        #expect(HomeTabBarItemContent.stats.accessibilityLabel == "Stats")
    }
}

@Suite("Home card streak layout")
struct HomeCardStreakLayoutTests {
    @Test("Streak button uses one edge inset for bottom and trailing padding")
    func streakButtonUsesSharedEdgeInset() {
        #expect(HomeCardStreakLayout.streakButtonEdgeInset == 12)
    }

    @Test("Won crossword distinguishes on-time and late labels")
    func wonCrosswordDistinguishesOnTimeAndLateLabels() {
        #expect(PuzzleStatus.completedOnTime.label == "Solved")
        #expect(PuzzleStatus.completedLate.label == "Finished")
    }

    @Test("Archive weekly status uses weekly release date")
    func archiveWeeklyStatusUsesWeeklyReleaseDate() throws {
        let puzzleId = "archive-weekly-status-\(UUID().uuidString)"
        UserProgress.delete(puzzleId: puzzleId)
        defer { UserProgress.delete(puzzleId: puzzleId) }

        var progress = UserProgress(
            puzzleId: puzzleId,
            size: 1,
            puzzleDate: "2026-07-05",
            totalClues: 1,
            isWeekly: true
        )
        progress.completedClueIds = [0]
        progress.completedAt = try #require(Self.date(from: "2026-07-09 12:00:00"))
        progress.save()

        let entry = ArchiveEntry(id: puzzleId, puzzleNumber: 1, date: "2026-07-05")

        #expect(PuzzleStatus.status(for: entry, isWeekly: true).label == "Solved")
        #expect(PuzzleStatus.status(for: entry, isWeekly: false).label == "Finished")
    }

    @Test("Archive weekly status is late after its release week")
    func archiveWeeklyStatusIsLateAfterReleaseWeek() throws {
        let puzzleId = "archive-weekly-late-status-\(UUID().uuidString)"
        UserProgress.delete(puzzleId: puzzleId)
        defer { UserProgress.delete(puzzleId: puzzleId) }

        var progress = UserProgress(
            puzzleId: puzzleId,
            size: 1,
            puzzleDate: "2026-07-05",
            totalClues: 1,
            isWeekly: true
        )
        progress.completedClueIds = [0]
        progress.completedAt = try #require(Self.date(from: "2026-07-12 12:00:00"))
        progress.save()

        let entry = ArchiveEntry(id: puzzleId, puzzleNumber: 1, date: "2026-07-05")

        #expect(PuzzleStatus.status(for: entry, isWeekly: true).label == "Finished")
    }

    private static func date(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: string)
    }
}

@Suite("Backword streak")
struct BackwordStreakTests {
    @Test("Live streak is visible for completions today")
    func liveStreakIncludesToday() {
        var stats = BackwordStats()
        stats.currentStreak = 3
        stats.lastCompletedDate = Self.dateString(for: Date())

        #expect(stats.liveCurrentStreak == 3)
    }

    @Test("Live streak hides stale completions")
    func liveStreakHidesStaleCompletion() {
        var stats = BackwordStats()
        stats.currentStreak = 3
        let staleDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        stats.lastCompletedDate = Self.dateString(for: staleDate)

        #expect(stats.liveCurrentStreak == 0)
    }

    private static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
