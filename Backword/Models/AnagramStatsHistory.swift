import Foundation

struct AnagramStatsHistoryRow {
    enum Outcome: Equatable {
        case unplayed
        case inProgress
        case solved
        case gaveUp
    }

    let dateStr: String
    let date: Date
    let isToday: Bool
    let score: Int
    let solveTime: Int?
    let outcome: Outcome
}

struct AnagramStatsHistory {
    let rows: [AnagramStatsHistoryRow]
    let currentStreak: Int
    let bestStreak: Int
    let totalSolved: Int
    let averageSolveTime: String

    static func make(
        rating: OverallRating,
        progressRecords: [AnagramProgress],
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar()
    ) -> AnagramStatsHistory {
        let calendar = releaseCalendar.calendar
        let today = releaseCalendar.dailyDateString
        let records = progressRecords.filter { $0.date != "review" && $0.date <= today }
        let progressByDate = Dictionary(records.map { ($0.date, $0) }, uniquingKeysWith: { current, candidate in
            candidate.updatedAt > current.updatedAt ? candidate : current
        })
        let eligibleSolves = progressByDate.values.filter { progress in
            progress.outcome == .solved && progress.releaseDateScore > 0 &&
                progress.completedAt.map { dateString($0, calendar: calendar) == progress.date } == true
        }

        let rows = (0..<14).compactMap { offset -> AnagramStatsHistoryRow? in
            guard let dateStr = releaseCalendar.dailyDateString(offsetByDays: -offset),
                  let date = date(from: dateStr, calendar: calendar) else { return nil }
            let progress = progressByDate[dateStr]
            let onTime = progress?.completedAt.map { dateString($0, calendar: calendar) == dateStr } == true
            let outcome: AnagramStatsHistoryRow.Outcome
            if let progress, onTime, progress.outcome == .solved, progress.releaseDateScore > 0 {
                outcome = .solved
            } else if let progress, onTime, progress.outcome == .gaveUp {
                outcome = .gaveUp
            } else if progress != nil, progress?.outcome == nil, dateStr == today {
                outcome = .inProgress
            } else {
                outcome = .unplayed
            }
            let score = outcome == .solved
                ? max(rating.score(for: .anagram, date: dateStr), progress?.releaseDateScore ?? 0)
                : 0
            return AnagramStatsHistoryRow(
                dateStr: dateStr,
                date: date,
                isToday: dateStr == today,
                score: score,
                solveTime: outcome == .solved ? progress?.elapsedSecondsAtCompletion : nil,
                outcome: outcome
            )
        }

        let solvedDates = eligibleSolves.compactMap { date(from: $0.date, calendar: calendar) }.sorted()
        var bestStreak = 0
        var streak = 0
        var previousDay: Date?
        for day in solvedDates {
            streak = previousDay.map { calendar.dateComponents([.day], from: $0, to: day).day == 1 } == true
                ? streak + 1 : 1
            bestStreak = max(bestStreak, streak)
            previousDay = day
        }

        let currentStreak = AnagramHomeCardSummary(
            progress: progressByDate[today], history: Array(progressByDate.values),
            now: releaseCalendar.now, calendar: calendar
        ).streak
        let averageSolveTime = CrosswordSolveTimeSummary.formattedAverageTime(
            from: rows.compactMap(\.solveTime)
        ) ?? "–"
        return AnagramStatsHistory(
            rows: rows, currentStreak: currentStreak, bestStreak: bestStreak,
            totalSolved: eligibleSolves.count, averageSolveTime: averageSolveTime
        )
    }

    private static func dateString(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func date(from value: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
