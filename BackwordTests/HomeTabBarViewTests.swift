import Foundation
import Testing
import SwiftUI
import UIKit
@testable import Backword

@Suite("Home games layout")
struct HomeGamesLayoutTests {
    @Test("Regular width arranges the four games in two columns")
    func regularWidthGames() {
        #expect(HomeGamesLayout.columns(for: .regular).count == 2)
        #expect(HomeGamesLayout.games == [
            .backword,
            .quickCrossword,
            .anagram,
            .proCrossword
        ])
    }

    @Test("Compact width keeps the games in one column")
    func compactWidthGames() {
        #expect(HomeGamesLayout.columns(for: .compact).count == 1)
        #expect(HomeGamesLayout.columns(for: nil).count == 1)
    }
}

@Suite("Home Word of the Day layout")
struct HomeWordOfTheDayLayoutTests {
    @Test("Wide viewports show the full Word of the Day on Home")
    func wideViewportShowsDetails() {
        #expect(!HomeWordOfTheDayLayout.showsInlineDetails(viewportWidth: 900, dynamicTypeSize: .large))
        #expect(HomeWordOfTheDayLayout.showsInlineDetails(viewportWidth: 901, dynamicTypeSize: .large))
        #expect(HomeWordOfTheDayLayout.showsInlineDetails(viewportWidth: 1_024, dynamicTypeSize: .xxxLarge))
    }

    @Test("Accessibility text sizes keep the compact Word of the Day button")
    func accessibilityTextUsesButton() {
        #expect(!HomeWordOfTheDayLayout.showsInlineDetails(viewportWidth: 1_366, dynamicTypeSize: .accessibility1))
    }

    @Test("The Home panel and detail sheet share the part-of-speech explanation")
    func partOfSpeechExplanation() {
        let word = WordOfTheDay(
            word: "Genuine",
            pronunciation: "JEN-yoo-in",
            partOfSpeech: "Adjective",
            definition: "Truly what something is said to be.",
            etymology: "From Latin genuinus.",
            synonyms: ["authentic"],
            exampleSentence: "Her smile was genuine."
        )

        #expect(word.partOfSpeechExplanation == "Adjective: a describing word that modifies a noun.")
    }
}

@Suite("Home tab bar")
struct HomeTabBarViewTests {
    #if DEBUG
    @Test("Home preview containers construct for default and completed states")
    @MainActor
    func homePreviewContainersConstruct() {
        _ = HomeViewPreviewContainer()
        _ = HomeViewPreviewContainer(completedPuzzle: true)
    }
    #endif

    @Test("App appearance defaults to System")
    func appAppearanceDefaultsToSystem() {
        #expect(AppColorSchemePreference.defaultValue == AppColorSchemePreference.systemValue)
        #expect(AppColorSchemePreference.colorScheme(for: AppColorSchemePreference.defaultValue) == nil)
    }

    @Test("App appearance maps explicit light and dark preferences")
    func appAppearanceMapsExplicitPreferences() {
        #expect(AppColorSchemePreference.colorScheme(for: AppColorSchemePreference.lightValue) == .light)
        #expect(AppColorSchemePreference.colorScheme(for: AppColorSchemePreference.darkValue) == .dark)
    }

    @Test("Home navigation icons use the larger shared glyph size")
    func homeNavigationIconGlyphSize() {
        #expect(AppLayout.homeNavigationIconGlyphSize == 20)
    }

    @Test("Debug settings shortcut remains a triple-tap")
    func debugSettingsShortcutTapCount() {
        #expect(HomeNavigationDebugGesturePolicy.tapCount == 3)
    }

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
    @Test("Home card issue numbers use the shared label and accessible name")
    func homeCardIssueNumberContent() {
        #expect(HomeCardIssueNumberContent.label(for: 123) == "#123")
        #expect(HomeCardIssueNumberContent.accessibilityLabel(for: 123) == "Issue #123")
    }

    @Test("Home card issue number overlay fits in the card's top whitespace")
    func homeCardIssueNumberLayout() {
        #expect(HomeCardIssueNumberLayout.horizontalInset == 14)
        #expect(HomeCardIssueNumberLayout.topInset == 10)
        #expect(AppLayout.homeCardIssueNumberFontSize == 12)
    }

    @Test("Anagram card stacks as soon as text grows beyond Large")
    func anagramCardResponsiveLayout() {
        #expect(!AnagramHomeCardLayout.usesStackedLayout(for: .large))
        #expect(AnagramHomeCardLayout.usesStackedLayout(for: .xLarge))
        #expect(AnagramHomeCardLayout.usesStackedLayout(for: .accessibility1))
    }

    @Test("Backword card always uses its dark colour palette")
    func backwordCardUsesDarkAppearance() {
        #expect(BackwordAppearance.colorScheme == .dark)
    }

    @Test("Backword card background follows the system appearance")
    func backwordCardBackgroundAppearance() {
        #expect(BackwordCardAppearance.backgroundColorScheme(for: .light) == .light)
        #expect(BackwordCardAppearance.backgroundColorScheme(for: .dark) == .dark)
    }

    @Test("Won Backword card cells use a white background only in Light Mode")
    func backwordCardWonCellStyle() {
        #expect(BackwordCardAppearance.correctCellStyle(for: .light) == .whiteHomeCard)
        #expect(BackwordCardAppearance.correctCellStyle(for: .dark) == .game)
    }

    @Test("Light Mode home card badges use a thin white border")
    func homeCardBadgeBorderStyle() {
        #expect(BackwordCardAppearance.badgeBorderStyle(for: .light) == .white)
        #expect(BackwordCardAppearance.badgeBorderStyle(for: .dark) == .none)
    }

    @Test("Home card backgrounds are brighter only in Light Mode")
    func homeCardBackgroundBrightness() {
        #expect(HomeCardAppearance.backgroundColorScheme(for: .light) == .light)
        #expect(HomeCardAppearance.backgroundColorScheme(for: .dark) == .dark)
        #expect(HomeCardAppearance.shouldBrightenBackground(for: .light))
        #expect(!HomeCardAppearance.shouldBrightenBackground(for: .dark))
        #expect(HomeCardAppearance.lightModeBrightnessOverlayOpacity == 0.1)
    }

    @Test("Backword status labels use the card's primary text colour")
    func backwordStatusUsesPrimaryText() {
        #expect(BackwordCardStatusStyle.textStyle == .primary)
    }

    @Test("Light Mode Backword New label uses the In Progress background")
    func backwordNewStatusBackgroundStyle() {
        #expect(
            BackwordCardStatusStyle.backgroundStyle(
                for: .notStarted,
                systemColorScheme: .light
            ) == .inProgress
        )
        #expect(
            BackwordCardStatusStyle.backgroundStyle(
                for: .inProgress,
                systemColorScheme: .light
            ) == .status
        )
        #expect(
            BackwordCardStatusStyle.backgroundStyle(
                for: .notStarted,
                systemColorScheme: .dark
            ) == .status
        )
    }

    @Test("Daily in-progress status labels use the card's primary text colour")
    func dailyInProgressStatusUsesPrimaryText() {
        #expect(DailyCrosswordCardStatusStyle.textStyle(for: .inProgress) == .primary)
        #expect(DailyCrosswordCardStatusStyle.textStyle(for: .notStarted) == .statusColor)
    }

    @Test("Daily card description matches the web home card colour")
    func dailyCardDescriptionColour() throws {
        let assetURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Backword/Resources/Assets.xcassets/DailyCardDescription.colorset/Contents.json")
        let data = try Data(contentsOf: assetURL)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let colors = try #require(json["colors"] as? [[String: Any]])
        let color = try #require(colors.first?["color"] as? [String: Any])
        let components = try #require(color["components"] as? [String: String])

        #expect(color["color-space"] as? String == "srgb")
        #expect(components == [
            "red": "0.705882",
            "green": "0.705882",
            "blue": "0.721569",
            "alpha": "1.000"
        ])
    }

    @Test("Streak button uses one edge inset for bottom and trailing padding")
    func streakButtonUsesSharedEdgeInset() {
        #expect(HomeCardStreakLayout.streakButtonEdgeInset == 12)
    }

    @Test("Won crossword distinguishes on-time and late labels")
    func wonCrosswordDistinguishesOnTimeAndLateLabels() {
        #expect(PuzzleStatus.completedOnTime.label == "Solved")
        #expect(PuzzleStatus.completedLate.label == "Finished")
    }

    @Test("Successful statuses use a white checkmark")
    func successfulStatusesUseWhiteCheckmark() {
        #expect(PuzzleStatus.completedOnTime.usesWhiteCheckmark)
        #expect(PuzzleStatus.completedLate.usesWhiteCheckmark)
        #expect(PuzzleStatus.wonBackwordOnTime(3).usesWhiteCheckmark)
        #expect(PuzzleStatus.wonBackword(3).usesWhiteCheckmark)
        #expect(!PuzzleStatus.failedBackword.usesWhiteCheckmark)
        #expect(!PuzzleStatus.gaveUp.usesWhiteCheckmark)
        #expect(!PuzzleStatus.inProgress.usesWhiteCheckmark)
        #expect(!PuzzleStatus.notStarted.usesWhiteCheckmark)
    }

    @Test("Anagram archive status distinguishes progress and completion outcomes")
    func anagramArchiveStatuses() {
        let puzzle = AnagramPuzzle(
            id: "anagram-status",
            date: "2026-09-26",
            puzzleNumber: 1,
            schemaVersion: 1,
            answer: "TRIANGLE",
            acceptedAnswers: ["INTEGRAL"],
            initialScramble: "RAGTLINE"
        )
        let start = Date(timeIntervalSince1970: 1_790_424_000)
        var progress = AnagramProgress(puzzle: puzzle, now: start)

        #expect(PuzzleStatus.status(for: Optional<AnagramProgress>.none).label == "New")
        #expect(PuzzleStatus.status(for: progress).label == "In Progress")

        progress.giveUp(now: start.addingTimeInterval(10))
        #expect(PuzzleStatus.status(for: progress).label == "Gave up")
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
        progress.completedAt = try Self.date(from: "2026-07-09 12:00:00")
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
        progress.completedAt = try Self.date(from: "2026-07-12 12:00:00")
        progress.save()

        let entry = ArchiveEntry(id: puzzleId, puzzleNumber: 1, date: "2026-07-05")

        #expect(PuzzleStatus.status(for: entry, isWeekly: true).label == "Finished")
    }

    @Test("Backword archive status uses gold for on-time wins")
    func backwordArchiveStatusUsesGoldForOnTimeWins() throws {
        var progress = BackwordProgress(date: "2026-07-09")
        progress.guesses = ["CASTLE"]
        progress.wonFlag = true
        progress.completedAt = try Self.date(from: "2026-07-09 12:00:00")

        let status = PuzzleStatus.status(for: progress, puzzleDate: "2026-07-09")

        guard case .wonBackwordOnTime(1) = status else {
            Issue.record("Expected on-time Backword win status, got \(status)")
            return
        }
        #expect(status.label == "1 guess")
    }

    @Test("Backword archive status uses correct green for late wins")
    func backwordArchiveStatusUsesCorrectGreenForLateWins() throws {
        var progress = BackwordProgress(date: "2026-07-09")
        progress.guesses = ["POETRY", "CASTLE"]
        progress.wonFlag = true
        progress.completedAt = try Self.date(from: "2026-07-10 12:00:00")

        let status = PuzzleStatus.status(for: progress, puzzleDate: "2026-07-09")

        guard case .wonBackword(2) = status else {
            Issue.record("Expected late Backword win status, got \(status)")
            return
        }
        #expect(status.label == "2 guesses")
    }

    private static func date(from string: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return try #require(formatter.date(from: string))
    }
}

@MainActor
@Suite("Anagram Home card sizing")
struct AnagramHomeCardSizingTests {
    private let cardWidth: CGFloat = 280

    @Test("Loaded Anagram card stays within a narrow Home column as text grows")
    func loadedCardFitsHomeColumn() {
        let puzzle = AnagramPuzzle(
            id: "anagram-home-sizing",
            date: "2026-09-29",
            puzzleNumber: 123,
            schemaVersion: 1,
            answer: "TRIANGLE",
            acceptedAnswers: ["INTEGRAL"],
            initialScramble: "RAGTLINE"
        )
        let progress = AnagramProgress(puzzle: puzzle, now: Date())
        let card = AnagramCard(
            puzzle: puzzle,
            summary: AnagramHomeCardSummary(progress: progress, history: [])
        ) {}

        for dynamicTypeSize in [DynamicTypeSize.large, .xLarge, .xxxLarge, .accessibility5] {
            #expect(fittingWidth(of: card, at: dynamicTypeSize) <= cardWidth + 0.5)
        }
    }

    @Test("Anagram loading and retry cards stay within a narrow Home column")
    func placeholderCardsFitHomeColumn() {
        for dynamicTypeSize in [DynamicTypeSize.large, .xLarge, .xxxLarge, .accessibility5] {
            for isLoading in [true, false] {
                let card = AnagramPlaceholderCard(isLoading: isLoading, retry: {})
                #expect(fittingWidth(of: card, at: dynamicTypeSize) <= cardWidth + 0.5)
            }
        }
    }

    private func fittingWidth<Content: View>(of content: Content, at dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let host = UIHostingController(rootView: content
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.dynamicTypeSize, dynamicTypeSize))
        return host.sizeThatFits(in: CGSize(width: cardWidth, height: 10_000)).width
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
