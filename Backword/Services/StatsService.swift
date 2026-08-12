import Foundation

@MainActor
final class StatsService: ObservableObject {

    @Published var stats: UserStats

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backword", isDirectory: true)
        return ProgressStorageNamespace.directory(base: base)
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
        migrateReleaseDayEligibility()
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

    /// Older stats files stored a completion timestamp but not whether that
    /// completion happened during the puzzle's release window. The progress
    /// record has both the release date and completion time, so it is the
    /// canonical source for rebuilding the new streak eligibility flag.
    private func migrateReleaseDayEligibility() {
        let progressByPuzzleID = Dictionary(
            uniqueKeysWithValues: UserProgress.loadAll().map { ($0.puzzleId, $0) }
        )
        var changed = false
        for index in stats.history.indices {
            guard let progress = progressByPuzzleID[stats.history[index].puzzleId] else { continue }
            let eligible = Self.isCompletedOnReleaseDate(progress)
            if stats.history[index].completedOnReleaseDate != eligible {
                stats.history[index].completedOnReleaseDate = eligible
                changed = true
            }
        }
        if changed {
            stats.recomputeAggregates()
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
                isWeekly: progress.isWeekly ?? false,
                completedOnReleaseDate: Self.isCompletedOnReleaseDate(progress)
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

        let completedOnReleaseDate = UserProgress.load(puzzleId: puzzleId)
            .map(Self.isCompletedOnReleaseDate) ?? false
        stats.recordCompletion(
            puzzleId: puzzleId,
            timeSeconds: timeSeconds,
            hintsUsed: hintsUsed,
            isWeekly: isWeekly,
            completedOnReleaseDate: completedOnReleaseDate
        )
        save()
    }

    func refreshForActiveProgress() {
        stats = UserStats()
        migrateFromUserProgress()
    }

    private func save() {
        let dir = Self.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(stats) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    private static func isCompletedOnReleaseDate(_ progress: UserProgress) -> Bool {
        guard progress.gaveUpAt == nil,
              let completedAt = progress.completedAt,
              let puzzleDate = progress.puzzleDate else { return false }
        let releaseCalendar = ContentReleaseCalendar(now: completedAt)
        let completionDate = progress.isWeekly == true
            ? releaseCalendar.weeklyDateString
            : releaseCalendar.dailyDateString
        return completionDate == puzzleDate
    }
}
