import Foundation

struct MidwordStatsHistoryRow {
    enum Outcome: Equatable {
        case unplayed
        case inProgress
        case solved
        case failed
    }

    let dateStr: String
    let date: Date
    let isToday: Bool
    let score: Int
    let guessCount: Int?
    let outcome: Outcome
}

struct MidwordStatsHistory {
    let rows: [MidwordStatsHistoryRow]
    let currentStreak: Int
    let bestStreak: Int
    let totalSolved: Int
    let guessDistribution: [Int: Int]

    static func make(
        rating: OverallRating,
        progressRecords: [MidwordProgress],
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar()
    ) -> MidwordStatsHistory {
        let calendar = releaseCalendar.calendar
        let today = releaseCalendar.dailyDateString
        let records = progressRecords.filter {
            $0.date >= OverallRating.midwordLaunchDate && $0.date <= today
        }
        let progressByDate = Dictionary(records.map { ($0.date, $0) }, uniquingKeysWith: { current, candidate in
            candidate.updatedAt > current.updatedAt ? candidate : current
        })
        // The snapshot preserves release-day eligibility across timezone changes
        // and whole-record merges with a later Archive attempt.
        let eligibleSolves = progressByDate.values.filter { progress in
            progress.isWon && progress.releaseDateScore > 0
        }

        let rows = (0..<14).compactMap { offset -> MidwordStatsHistoryRow? in
            guard let dateStr = releaseCalendar.dailyDateString(offsetByDays: -offset),
                  dateStr >= OverallRating.midwordLaunchDate,
                  let date = date(from: dateStr, calendar: calendar) else { return nil }
            let progress = progressByDate[dateStr]
            let onTime = progress?.completedAt.map { dateString($0, calendar: calendar) == dateStr } == true
            let outcome: MidwordStatsHistoryRow.Outcome
            if let progress, progress.isWon, progress.releaseDateScore > 0 {
                outcome = .solved
            } else if let progress, onTime, progress.isFailed {
                outcome = .failed
            } else if progress != nil, progress?.isComplete == false, dateStr == today {
                outcome = .inProgress
            } else {
                outcome = .unplayed
            }
            let score = outcome == .solved
                ? max(rating.score(for: .midword, date: dateStr), progress?.releaseDateScore ?? 0)
                : 0
            return MidwordStatsHistoryRow(
                dateStr: dateStr,
                date: date,
                isToday: dateStr == today,
                score: score,
                guessCount: outcome == .solved ? progress?.guesses.count : nil,
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

        let solvedDateStrings = Set(eligibleSolves.map(\.date))
        var currentStreak = 0
        if progressByDate[today]?.isFailed != true {
            var offset = solvedDateStrings.contains(today) ? 0 : 1
            while let date = releaseCalendar.dailyDateString(offsetByDays: -offset), solvedDateStrings.contains(date) {
                currentStreak += 1
                offset += 1
            }
        }

        let distribution = Dictionary(grouping: eligibleSolves, by: { $0.guesses.count })
            .mapValues(\.count)
        return MidwordStatsHistory(
            rows: rows,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalSolved: eligibleSolves.count,
            guessDistribution: distribution
        )
    }

    private static func dateString(_ date: Date, calendar: Calendar) -> String {
        formatter(calendar: calendar).string(from: date)
    }

    private static func date(from value: String, calendar: Calendar) -> Date? {
        formatter(calendar: calendar).date(from: value)
    }

    private static func formatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
