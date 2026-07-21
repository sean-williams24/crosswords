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

    @Test("Daily crossword tab content")
    func dailyTabContent() {
        let content = ArchiveTabBarItemContent.content(for: .daily)

        #expect(content.title == "Daily")
        #expect(content.accessibilityLabel == "Daily crossword archive")
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
