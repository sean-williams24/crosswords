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
