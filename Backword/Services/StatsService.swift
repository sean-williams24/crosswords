import Foundation

@MainActor
final class StatsService: ObservableObject {

    @Published var stats: UserStats

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backword", isDirectory: true)
            .appendingPathComponent("stats.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let decoded = try? JSONDecoder().decode(UserStats.self, from: data) {
            self.stats = decoded
        } else {
            self.stats = UserStats()
        }
        migrateWeeklyFlags()
        migrateFromUserProgress()
    }

    /// One-time migration: for any PuzzleResult stored before isWeekly was introduced,
    /// check its UserProgress file (which already tracks isWeekly) and fix the flag.
    private func migrateWeeklyFlags() {
        var changed = false
        for i in stats.history.indices {
            guard !stats.history[i].isWeekly else { continue }
            if UserProgress.load(puzzleId: stats.history[i].puzzleId)?.isWeekly == true {
                stats.history[i].isWeekly = true
                changed = true
            }
        }
        if changed { save() }
    }

    /// Backfills StatsService history from UserProgress files for any completed puzzles
    /// that were never recorded (e.g. completed before CompletionView wired up StatsService).
    private func migrateFromUserProgress() {
        let existingIds = Set(stats.history.map { $0.puzzleId })
        var added = false

        for progress in UserProgress.loadAll() {
            guard progress.isComplete,
                  progress.gaveUpAt == nil,
                  let completedAt = progress.completedAt,
                  !existingIds.contains(progress.puzzleId) else { continue }

            let result = PuzzleResult(
                puzzleId: progress.puzzleId,
                date: Calendar.current.startOfDay(for: completedAt),
                timeSeconds: Int(progress.elapsedTime),
                hintsUsed: progress.hintsUsed,
                isWeekly: progress.isWeekly ?? false
            )
            stats.history.append(result)
            added = true
        }

        guard added else { return }

        stats.history.sort { $0.date < $1.date }

        // Recompute aggregate stats from full history
        let allHistory = stats.history
        stats.totalCompleted = allHistory.count
        if !allHistory.isEmpty {
            stats.averageTimeSeconds = Double(allHistory.reduce(0) { $0 + $1.timeSeconds }) / Double(allHistory.count)
        }

        // Recompute daily streak
        let calendar = Calendar.current
        let dailyDates = allHistory
            .filter { !$0.isWeekly }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()

        if let lastDate = dailyDates.last {
            stats.lastCompletedDate = lastDate
            let today = calendar.startOfDay(for: Date())
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if calendar.isDate(lastDate, inSameDayAs: today) || calendar.isDate(lastDate, inSameDayAs: yesterday) {
                var streak = 1
                for i in stride(from: dailyDates.count - 1, through: 1, by: -1) {
                    let gap = calendar.dateComponents([.day], from: dailyDates[i - 1], to: dailyDates[i]).day ?? Int.max
                    if gap <= 1 { streak += 1 } else { break }
                }
                stats.currentStreak = streak
            } else {
                stats.currentStreak = 0
            }
            var longest = 1, current = 1
            for i in 1..<dailyDates.count {
                let gap = calendar.dateComponents([.day], from: dailyDates[i - 1], to: dailyDates[i]).day ?? Int.max
                if gap <= 1 { current += 1; longest = max(longest, current) } else { current = 1 }
            }
            stats.longestStreak = longest
        }

        save()
    }

    func recordCompletion(puzzleId: String, timeSeconds: Int, hintsUsed: Int, isWeekly: Bool = false) {
        // Avoid duplicate records for the same puzzle
        guard !stats.history.contains(where: { $0.puzzleId == puzzleId }) else { return }

        stats.recordCompletion(puzzleId: puzzleId, timeSeconds: timeSeconds, hintsUsed: hintsUsed, isWeekly: isWeekly)
        save()
    }

    private func save() {
        let dir = Self.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(stats) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
