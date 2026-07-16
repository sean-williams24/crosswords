import Foundation

struct CrosswordSolveTimeSummary {
    static func solveTimeByDailyDate(from progressRecords: [UserProgress]) -> [String: Int] {
        Dictionary(
            progressRecords.compactMap { progress -> (String, Int)? in
                guard let puzzleDate = progress.puzzleDate,
                      let solveTime = solveTime(from: progress, isWeekly: false) else { return nil }

                return (puzzleDate, solveTime)
            },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    static func formattedAverageTime(from progressRecords: [UserProgress], isWeekly: Bool) -> String? {
        let solveTimes = progressRecords.compactMap { solveTime(from: $0, isWeekly: isWeekly) }
        return formattedAverageTime(from: solveTimes)
    }

    static func formattedAverageTime(from solveTimes: [Int]) -> String? {
        guard !solveTimes.isEmpty else { return nil }

        let average = Double(solveTimes.reduce(0, +)) / Double(solveTimes.count)
        return Int(average).formattedTimeHHMMSS
    }

    static func solveTime(from progress: UserProgress, isWeekly: Bool) -> Int? {
        guard progress.gaveUpAt == nil,
              let puzzleDate = progress.puzzleDate,
              let completedAt = progress.completedAt else { return nil }

        if isWeekly {
            guard progress.isWeekly == true else { return nil }
        } else {
            guard progress.isWeekly != true else { return nil }
        }

        let releaseDateString = isWeekly
            ? ContentReleaseCalendar(now: completedAt).weeklyDateString
            : ContentReleaseCalendar(now: completedAt).dailyDateString

        guard releaseDateString == puzzleDate else { return nil }

        return Int(progress.elapsedTime)
    }
}
