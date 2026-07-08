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

    @Test("Won crossword shows finished label")
    func wonCrosswordShowsFinishedLabel() {
        #expect(PuzzleStatus.completedOnTime.label == "Finished")
        #expect(PuzzleStatus.completedLate.label == "Finished")
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
