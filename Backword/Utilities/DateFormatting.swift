//  ContentReleaseCalendar.swift

import Foundation

struct ContentReleaseCalendar {
    var now: Date
    var calendar: Calendar

    init(now: Date = Date(), timeZone: TimeZone = .current) {
        self.now = now
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    init(now: Date = Date(), calendar: Calendar) {
        self.now = now
        self.calendar = calendar
    }

    var dailyDateString: String {
        dateString(from: now)
    }

    var weeklyDateString: String {
        dateString(from: startOfCurrentWeek)
    }

    var formattedToday: String {
        let fmt = DateFormatter()
        fmt.calendar = calendar
        fmt.timeZone = calendar.timeZone
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt.string(from: now).capitalized
    }

    var nextDailyRefreshDate: Date? {
        calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        )
    }

    var nextWeeklyRefreshDate: Date? {
        calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0, weekday: 1),
            matchingPolicy: .nextTime
        )
    }

    func secondsUntilDailyRefresh() -> TimeInterval? {
        nextDailyRefreshDate?.timeIntervalSince(now)
    }

    func secondsUntilWeeklyRefresh() -> TimeInterval? {
        nextWeeklyRefreshDate?.timeIntervalSince(now)
    }

    func dailyDateString(offsetByDays offset: Int) -> String? {
        guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
        return dateString(from: date)
    }

    func month(for type: ArchiveGameType) -> ArchiveMonth {
        let date = type == .weekly ? startOfCurrentWeek : now
        return ArchiveMonth.current(date: date, calendar: calendar)
    }

    private var startOfCurrentWeek: Date {
        let startOfToday = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: startOfToday)
        let daysSinceSunday = weekday - 1
        return calendar.date(byAdding: .day, value: -daysSinceSunday, to: startOfToday) ?? startOfToday
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

final class DateFormatting {
    func todayString() -> String {
        ContentReleaseCalendar().dailyDateString
    }

    func weeklyContentDateString() -> String {
        ContentReleaseCalendar().weeklyDateString
    }

    var formatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }

    var formattedDate: String {
        ContentReleaseCalendar().formattedToday
    }
}
