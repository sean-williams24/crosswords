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
