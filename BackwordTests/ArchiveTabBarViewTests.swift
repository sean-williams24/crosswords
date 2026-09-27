import Testing
@testable import Backword

@Suite("Archive tab bar")
struct ArchiveTabBarViewTests {
    @Test("Backword tab content")
    func backwordTabContent() {
        let content = ArchiveTabBarItemContent.content(for: .backword)

        #expect(content.title == "Backword")
        #expect(content.accessibilityLabel == "Backword archive")
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

@Suite("Backword archive row")
struct BackwordArchiveRowTests {
    @Test("Displays the connection clue above the formatted date")
    func archiveDetails() {
        let word = BackwordWord(
            id: "archive-word",
            date: "2026-07-20",
            word: "CASTLE",
            clue: "CHESS"
        )

        let content = BackwordArchiveRowContent(word: word, today: "2026-07-20")

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
