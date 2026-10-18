import Testing
import SwiftUI
@testable import Backword

@Suite("Archive tab bar")
struct ArchiveTabBarViewTests {
    @Test("Uses one row at standard Dynamic Type sizes")
    func regularLayout() {
        #expect(ArchiveTabBarLayout.layout(for: .medium) == .singleRow)
        #expect(ArchiveTabBarLayout.layout(for: .large) == .singleRow)
        #expect(ArchiveTabBarLayout.layout(for: .xxxLarge) == .singleRow)
        #expect(ArchiveTabBarLayout.singleRow.height == 54)
        #expect(ArchiveTabBarLayout.singleRow.archiveContentBottomPadding == 112)
        #expect(ArchiveTabBarLayout.singleRow.containerCornerRadius == 25)
        #expect(ArchiveTabBarLayout.minimumTitleScaleFactor == 0.75)
    }

    @Test("Uses two rows at accessibility Dynamic Type sizes")
    func accessibleLayout() {
        #expect(ArchiveTabBarLayout.layout(for: .accessibility1) == .twoRowGrid)
        #expect(ArchiveTabBarLayout.layout(for: .accessibility5) == .twoRowGrid)
        #expect(ArchiveTabBarLayout.twoRowGrid.height == 108)
        #expect(ArchiveTabBarLayout.twoRowGrid.archiveContentBottomPadding == 166)
        #expect(ArchiveTabBarLayout.twoRowGrid.containerCornerRadius == 25)
    }

    @Test("Splits five tabs across two centred rows")
    func splitLayoutRows() {
        let rows = ArchiveTabBarLayout.rows(for: ArchiveTab.allCases)

        #expect(rows.count == 2)
        #expect(rows[0] == [.backword, .midword, .daily])
        #expect(rows[1] == [.anagram, .weekly])
    }

    @Test("Backword tab content")
    func backwordTabContent() {
        let content = ArchiveTabBarItemContent.content(for: .backword)

        #expect(content.title == "Backword")
        #expect(content.accessibilityLabel == "Backword archive")
    }

    @Test("Midword tab content")
    func midwordTabContent() {
        let content = ArchiveTabBarItemContent.content(for: .midword)
        #expect(content.title == "Midword")
        #expect(content.accessibilityLabel == "Midword archive")
    }

    @Test("Quick crossword tab content")
    func quickTabContent() {
        let content = ArchiveTabBarItemContent.content(for: .daily)

        #expect(content.title == "Quick")
        #expect(content.accessibilityLabel == "Quick crossword archive")
        #expect(ArchiveTab.daily.rawValue == "Quick\n Crossword")
    }

    @Test("Anagram tab content")
    func anagramTabContent() {
        let content = ArchiveTabBarItemContent.content(for: .anagram)

        #expect(content.title == "Anagram")
        #expect(content.accessibilityLabel == "Anagram archive")
    }

    @Test("Pro crossword tab content")
    func weeklyTabContent() {
        let content = ArchiveTabBarItemContent.content(for: .weekly)

        #expect(content.title == "Pro")
        #expect(content.accessibilityLabel == "Pro crossword archive")
    }
}

@Suite("Archive issue and date layout")
struct ArchiveIssueDateLayoutTests {
    @Test("Keeps metadata inline at standard Dynamic Type sizes")
    func inlineLayout() {
        #expect(!ArchiveIssueDateLayout.stacksVertically(for: .large))
        #expect(!ArchiveIssueDateLayout.stacksVertically(for: .xxxLarge))
    }

    @Test("Stacks metadata at accessibility Dynamic Type sizes")
    func stackedLayout() {
        #expect(ArchiveIssueDateLayout.stacksVertically(for: .accessibility1))
        #expect(ArchiveIssueDateLayout.stacksVertically(for: .accessibility5))
    }
}

@Suite("Backword archive row")
struct BackwordArchiveRowTests {
    @Test("Formats the issue, date, and clue for the shared archive-card layout")
    func archiveDetails() {
        let word = BackwordWord(
            id: "archive-word",
            date: "2026-07-20",
            puzzleNumber: 42,
            word: "CASTLE",
            clue: "CHESS"
        )

        let content = BackwordArchiveRowContent(word: word, today: "2026-07-20")

        #expect(content.issueNumber == "# 42")
        #expect(content.clue == "CHESS")
        #expect(content.formattedDate == "Monday, Jul 20")
        #expect(content.isToday)
    }
}

@Suite("Crossword archive row")
struct ArchivePuzzleRowTests {
    @Test("Formats the puzzle number above the date")
    func puzzleNumber() {
        #expect(ArchivePuzzleRowContent.puzzleNumber(23) == "# 23")
    }
}

@Suite("Midword archive row")
struct MidwordArchiveRowTests {
    @Test("Formats the clue, date, and issue for the shared archive-card layout")
    func archiveDetails() {
        let puzzle = MidwordPuzzle(
            id: "archive-midword",
            date: "2026-10-01",
            puzzleNumber: 42,
            firstWord: "PAGE",
            secondWord: "CASE",
            answer: "TURN",
            alternatives: []
        )

        let content = MidwordArchiveRowContent(puzzle: puzzle, today: "2026-10-01")

        #expect(content.clue == "PAGE  ·  ?  ·  CASE")
        #expect(content.formattedDate == "Thursday, Oct 1")
        #expect(content.issueNumber == "# 42")
        #expect(content.isToday)
    }
}

@Suite("Anagram archive row")
struct AnagramArchiveRowTests {
    @Test("Formats the issue and date like the other archive rows")
    func archiveDetails() {
        let puzzle = AnagramPuzzle(
            id: "archive-anagram",
            date: "2026-09-26",
            puzzleNumber: 12,
            schemaVersion: 1,
            answer: "TRIANGLE",
            acceptedAnswers: ["INTEGRAL"],
            initialScramble: "RAGTLINE"
        )

        let content = AnagramArchiveRowContent(puzzle: puzzle, today: "2026-09-26")

        #expect(content.issueNumber == "# 12")
        #expect(content.formattedDate == "Saturday, Sep 26")
        #expect(content.isToday)
    }
}
