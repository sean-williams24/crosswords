import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Centred Home game card content")
struct HomeGameCardContentTests {
    @Test("Brand and completion details fit narrow cards as text grows",
          arguments: [DynamicTypeSize.large, .xLarge, .accessibility5])
    func contentFitsNarrowCard(dynamicTypeSize: DynamicTypeSize) {
        let card = HomeGameCardContent(minimumHeight: AppLayout.cardHeightSmall) {
            Text("QUICK\nCROSSWORD")
                .font(AppFont.clueLabel(16))
        } details: {
            VStack(alignment: .trailing) {
                Text("In Progress")
                    .font(AppFont.caption())
                Text("4 / 5    12-day streak")
                    .font(AppFont.caption())
            }
        }
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        let host = UIHostingController(rootView: card)
        let size = host.sizeThatFits(in: CGSize(width: 280, height: 10_000))

        #expect(size.width <= 280.5)
        #expect(size.height >= AppLayout.cardHeightSmall)
    }

    @Test("Midword Home streak uses release-day wins and resets when records change")
    func midwordHomeStreak() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-12T12:00:00Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let releaseCalendar = ContentReleaseCalendar(now: now, calendar: calendar)
        var yesterday = MidwordProgress(date: "2026-10-11")
        yesterday.completedAt = now.addingTimeInterval(-86_400)
        yesterday.won = true
        yesterday.releaseDateScore = 5
        var today = MidwordProgress(date: "2026-10-12")
        today.completedAt = now
        today.won = true
        today.releaseDateScore = 4
        let service = MidwordService()
        service.refreshStats(progressRecords: [yesterday, today], releaseCalendar: releaseCalendar)
        #expect(service.currentStreak == 2)
        today.won = false
        today.releaseDateScore = 0
        service.refreshStats(progressRecords: [yesterday, today], releaseCalendar: releaseCalendar)
        #expect(service.currentStreak == 0)
        service.refreshStats(progressRecords: [yesterday], releaseCalendar: releaseCalendar)
        #expect(service.currentStreak == 1)
        service.refreshStats(progressRecords: [], releaseCalendar: releaseCalendar)
        #expect(service.currentStreak == 0)
    }

    @Test("Cards without an issue or score retain their minimum height")
    func placeholderKeepsCardHeight() {
        let card = HomeGameCardContent(minimumHeight: AppLayout.cardHeightSmall) {
            Text("ANAGRAM")
                .font(AppFont.clueLabel(24))
        } details: {
            ProgressView()
        }
        let host = UIHostingController(rootView: card)
        let size = host.sizeThatFits(in: CGSize(width: 280, height: 10_000))

        #expect(size.width <= 280.5)
        #expect(size.height >= AppLayout.cardHeightSmall)
    }
}
