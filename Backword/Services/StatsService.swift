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
        removeGaveUpCompletions()
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

    private func removeGaveUpCompletions() {
        let gaveUpPuzzleIds = Set(
            UserProgress.loadAll()
                .filter { $0.gaveUpAt != nil }
                .map(\.puzzleId)
        )
        let previousCount = stats.history.count
        stats.removeResults(puzzleIds: gaveUpPuzzleIds)
        if stats.history.count != previousCount {
            save()
        }
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

        stats.recomputeAggregates()
        save()
    }

    func recordCompletion(puzzleId: String, timeSeconds: Int, hintsUsed: Int, isWeekly: Bool = false) {
        guard UserProgress.load(puzzleId: puzzleId)?.gaveUpAt == nil else { return }
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
