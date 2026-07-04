import Foundation
import Testing
@testable import Backword

@Suite("Content Release Calendar Tests")
struct ContentReleaseCalendarTests {

    @Test("Daily date follows local day in US Eastern")
    func dailyDateFollowsUSEasternLocalDay() throws {
        let calendar = releaseCalendar(timeZoneIdentifier: "America/New_York")
        let date = try date("2026-05-10T01:30:00Z") // May 9, 9:30 PM in New York

        let releaseCalendar = ContentReleaseCalendar(now: date, calendar: calendar)

        #expect(releaseCalendar.dailyDateString == "2026-05-09")
    }

    @Test("Daily date follows local day in Canada Pacific")
    func dailyDateFollowsCanadaPacificLocalDay() throws {
        let calendar = releaseCalendar(timeZoneIdentifier: "America/Vancouver")
        let date = try date("2026-05-10T06:30:00Z") // May 9, 11:30 PM in Vancouver

        let releaseCalendar = ContentReleaseCalendar(now: date, calendar: calendar)

        #expect(releaseCalendar.dailyDateString == "2026-05-09")
    }

    @Test("Daily date follows local day in Europe")
    func dailyDateFollowsEuropeLocalDay() throws {
        let calendar = releaseCalendar(timeZoneIdentifier: "Europe/London")
        let date = try date("2026-05-09T23:30:00Z") // May 10, 12:30 AM in London

        let releaseCalendar = ContentReleaseCalendar(now: date, calendar: calendar)

        #expect(releaseCalendar.dailyDateString == "2026-05-10")
    }

    @Test("Daily date follows local day in Australia")
    func dailyDateFollowsAustraliaLocalDay() throws {
        let calendar = releaseCalendar(timeZoneIdentifier: "Australia/Sydney")
        let date = try date("2026-05-09T14:30:00Z") // May 10, 12:30 AM in Sydney

        let releaseCalendar = ContentReleaseCalendar(now: date, calendar: calendar)

        #expect(releaseCalendar.dailyDateString == "2026-05-10")
    }

    @Test("Weekly date is most recent local Sunday")
    func weeklyDateIsMostRecentLocalSunday() throws {
        let calendar = releaseCalendar(timeZoneIdentifier: "Australia/Sydney")
        let saturday = ContentReleaseCalendar(now: try date("2026-05-09T13:30:00Z"), calendar: calendar)
        let sunday = ContentReleaseCalendar(now: try date("2026-05-09T14:30:00Z"), calendar: calendar)

        #expect(saturday.weeklyDateString == "2026-05-03")
        #expect(sunday.weeklyDateString == "2026-05-10")
    }

    @Test("Daily refresh is next local midnight")
    func dailyRefreshIsNextLocalMidnight() throws {
        let calendar = releaseCalendar(timeZoneIdentifier: "Australia/Sydney")
        let now = try date("2026-05-09T13:30:00Z") // May 9, 11:30 PM in Sydney
        let releaseCalendar = ContentReleaseCalendar(now: now, calendar: calendar)

        #expect(releaseCalendar.secondsUntilDailyRefresh() == 1_800)
    }

    @Test("Daily refresh countdown covers final local hour in UK")
    func dailyRefreshCountdownCoversFinalLocalHourInUK() throws {
        let calendar = releaseCalendar(timeZoneIdentifier: "Europe/London")
        let now = try date("2026-07-03T22:15:00Z") // July 3, 11:15 PM in London
        let releaseCalendar = ContentReleaseCalendar(now: now, calendar: calendar)

        #expect(releaseCalendar.secondsUntilDailyRefresh() == 2_700)
    }

    @Test("Weekly refresh is next local Sunday midnight")
    func weeklyRefreshIsNextLocalSundayMidnight() throws {
        let calendar = releaseCalendar(timeZoneIdentifier: "America/New_York")
        let now = try date("2026-05-08T16:00:00Z") // Friday noon in New York
        let releaseCalendar = ContentReleaseCalendar(now: now, calendar: calendar)

        #expect(releaseCalendar.secondsUntilWeeklyRefresh() == 129_600)
    }

    @Test("Rating window ends on local daily content date")
    func ratingWindowEndsOnLocalDailyContentDate() throws {
        let calendar = releaseCalendar(timeZoneIdentifier: "Australia/Sydney")
        let now = try date("2026-05-09T14:30:00Z") // May 10 in Sydney

        let range = OverallRating.windowDateRange(now: now, calendar: calendar)

        #expect(range.today == "2026-05-10")
        #expect(range.cutoff == "2026-04-27")
    }

    private func releaseCalendar(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }

    private func date(_ isoString: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        return try #require(formatter.date(from: isoString))
    }
}
