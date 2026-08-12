import Foundation

struct BackwordStatsHistoryRow {
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

struct BackwordStatsHistory {
    static let dayCount = 14

    let rows: [BackwordStatsHistoryRow]

    static func make(
        rating: OverallRating,
        progressRecords: [BackwordProgress],
        releaseCalendar: ContentReleaseCalendar = ContentReleaseCalendar()
    ) -> BackwordStatsHistory {
        let scoreByDate = Dictionary(
            rating.dailyScores.map { ($0.date, $0.backword) },
            uniquingKeysWith: { first, _ in first }
        )
        let progressByDate = Dictionary(
            progressRecords.map { ($0.date, $0) },
            uniquingKeysWith: preferredProgress
        )
        let today = releaseCalendar.dailyDateString

        let rows = (0..<dayCount).compactMap { offset -> BackwordStatsHistoryRow? in
            guard
                let dateStr = releaseCalendar.dailyDateString(offsetByDays: -offset),
                let date = date(from: dateStr, calendar: releaseCalendar.calendar)
            else {
                return nil
            }

            // Keep Archive progress in account storage for cross-device
            // continuation, but exclude it from the stats history entirely.
            // A release-date result is the only kind of Backword game that
            // can show guesses, a status, or a score in this surface.
            let progress = progressByDate[dateStr]
            let statsProgress = progress?.wasCompletedOnReleaseDate == true ? progress : nil
            return BackwordStatsHistoryRow(
                dateStr: dateStr,
                date: date,
                isToday: dateStr == today,
                score: statsProgress.map { scoreByDate[dateStr] ?? $0.completedScore ?? 0 } ?? 0,
                guessCount: statsProgress.map(\.guesses.count),
                outcome: outcome(for: statsProgress)
            )
        }

        return BackwordStatsHistory(rows: rows)
    }

    private static func outcome(for progress: BackwordProgress?) -> BackwordStatsHistoryRow.Outcome {
        guard let progress else { return .unplayed }
        if progress.isWon { return .solved }
        if progress.isFailed { return .failed }
        return .inProgress
    }

    private static func preferredProgress(
        _ current: BackwordProgress,
        _ candidate: BackwordProgress
    ) -> BackwordProgress {
        if current.isComplete != candidate.isComplete {
            return candidate.isComplete ? candidate : current
        }
        return candidate.guesses.count > current.guesses.count ? candidate : current
    }

    private static func date(from dateString: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}
