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
    }

    func recordCompletion(puzzleId: String, timeSeconds: Int, hintsUsed: Int) {
        // Avoid duplicate records for the same puzzle
        guard !stats.history.contains(where: { $0.puzzleId == puzzleId }) else { return }

        stats.recordCompletion(puzzleId: puzzleId, timeSeconds: timeSeconds, hintsUsed: hintsUsed)
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
