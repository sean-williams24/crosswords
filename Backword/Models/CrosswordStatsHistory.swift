import Foundation

struct CrosswordStatsHistoryRow {
    let dateStr: String
    let date: Date
    let isToday: Bool
    let score: Int
    let solveTime: Int?
    let isSolved: Bool
}

struct WeeklyCrosswordStatsHistory {
    static let recentGameCount = 2
    static let previousGameCount = 5

    let last14Days: [CrosswordStatsHistoryRow]
    let previousGames: [CrosswordStatsHistoryRow]

    var allRows: [CrosswordStatsHistoryRow] {
        last14Days + previousGames
    }

    static func make(
        rating: OverallRating,
        progressRecords: [UserProgress],
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar()
    ) -> WeeklyCrosswordStatsHistory {
        let scoreByDate = Dictionary(
            rating.dailyScores.compactMap { entry -> (String, Int)? in
                guard let weeklyScore = entry.weeklyCrossword else { return nil }
                return (entry.date, weeklyScore)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let progressByDate = Dictionary(
            progressRecords.compactMap { progress -> (String, UserProgress)? in
                guard progress.isWeekly == true,
                      let puzzleDate = progress.puzzleDate else { return nil }
                return (puzzleDate, progress)
            },
            uniquingKeysWith: preferredProgress
        )

        guard let currentWeeklyDate = date(
            from: releaseCalendar.weeklyDateString,
            calendar: releaseCalendar.calendar
        ) else {
            return WeeklyCrosswordStatsHistory(last14Days: [], previousGames: [])
        }

        let rowCount = recentGameCount + previousGameCount
        let rows = (0..<rowCount).compactMap { offset -> CrosswordStatsHistoryRow? in
            guard let date = releaseCalendar.calendar.date(
                byAdding: .weekOfYear,
                value: -offset,
                to: currentWeeklyDate
            ) else {
                return nil
            }
            let dateStr = dateString(from: date, calendar: releaseCalendar.calendar)

            let progress = progressByDate[dateStr]
            let solveTime = progress.flatMap {
                CrosswordSolveTimeSummary.solveTime(from: $0, isWeekly: true)
            }
            let ratingScore = scoreByDate[dateStr]
            // OverallRating retains only the rolling window, while this view
            // deliberately shows five older weekly games as well. Read the
            // durable score snapshot from the matching progress record once
            // its aggregate-rating entry has rolled out of that window.
            let progressScore = progress?.releaseDateScore

            return CrosswordStatsHistoryRow(
                dateStr: dateStr,
                date: date,
                isToday: dateStr == releaseCalendar.dailyDateString,
                score: ratingScore ?? progressScore ?? (solveTime != nil ? 5 : 0),
                solveTime: solveTime,
                isSolved: solveTime != nil
            )
        }

        return WeeklyCrosswordStatsHistory(
            last14Days: Array(rows.prefix(recentGameCount)),
            previousGames: Array(rows.dropFirst(recentGameCount))
        )
    }

    private static func preferredProgress(
        _ current: UserProgress,
        _ candidate: UserProgress
    ) -> UserProgress {
        if current.completedAt == nil, candidate.completedAt != nil {
            return candidate
        }
        if current.gaveUpAt != nil, candidate.gaveUpAt == nil {
            return candidate
        }
        return current
    }

    private static func date(from dateString: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    private static func dateString(from date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
