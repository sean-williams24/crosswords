import Foundation

struct ArchiveMonth: Codable, Hashable, Identifiable, Comparable {
    let year: Int
    let month: Int

    var id: String { key }

    var key: String {
        String(format: "%04d-%02d", year, month)
    }

    var startDateString: String {
        "\(key)-01"
    }

    var displayName: String {
        guard let date = Self.monthFormatter.date(from: key) else { return key }
        return Self.displayFormatter.string(from: date)
    }

    var shortDisplayName: String {
        guard let date = Self.monthFormatter.date(from: key) else { return key }
        return Self.shortDisplayFormatter.string(from: date)
    }

    static func < (lhs: ArchiveMonth, rhs: ArchiveMonth) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        return lhs.month < rhs.month
    }

    static func current(date: Date = Date(), calendar: Calendar = utcCalendar) -> ArchiveMonth {
        let components = calendar.dateComponents([.year, .month], from: date)
        return ArchiveMonth(year: components.year ?? 1970, month: components.month ?? 1)
    }

    static func from(dateString: String) -> ArchiveMonth? {
        let parts = dateString.split(separator: "-")
        guard parts.count >= 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              (1...12).contains(month) else {
            return nil
        }
        return ArchiveMonth(year: year, month: month)
    }

    func contains(dateString: String) -> Bool {
        dateString.hasPrefix(key)
    }

    func dateRange(calendar: Calendar = utcCalendar) -> ClosedRange<String> {
        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = month
        components.day = 1

        guard let start = calendar.date(from: components),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: start),
              let end = calendar.date(byAdding: .day, value: -1, to: nextMonth) else {
            return startDateString...startDateString
        }

        return Self.dateFormatter.string(from: start)...Self.dateFormatter.string(from: end)
    }

    private static var utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let shortDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

enum ArchiveGameType: String, CaseIterable, Codable, Hashable {
    case backword
    case daily
    case weekly
}

struct ArchiveMonthContent: Equatable {
    var dailyPuzzles: [Puzzle] = []
    var weeklyPuzzles: [Puzzle] = []
    var backwordWords: [BackwordWord] = []

    func isEmpty(for type: ArchiveGameType) -> Bool {
        switch type {
        case .backword:
            return backwordWords.isEmpty
        case .daily:
            return dailyPuzzles.isEmpty
        case .weekly:
            return weeklyPuzzles.isEmpty
        }
    }
}
