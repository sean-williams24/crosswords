import Foundation

struct BackwordStats: Codable {
    var gamesPlayed: Int
    var gamesWon: Int
    var currentStreak: Int
    var longestStreak: Int
    /// Histogram: guess count (1–5) → number of wins at that count
    var guessCounts: [String: Int]
    var lastCompletedDate: String?

    init() {
        gamesPlayed = 0
        gamesWon = 0
        currentStreak = 0
        longestStreak = 0
        guessCounts = [:]
        lastCompletedDate = nil
    }

    // MARK: - Recording

    mutating func record(guessCount: Int?, date: String) {
        gamesPlayed += 1

        if let count = guessCount {
            // Win
            gamesWon += 1
            let key = "\(count)"
            guessCounts[key, default: 0] += 1

            // Streak: consecutive calendar days
            if let last = lastCompletedDate,
               let lastDate = Self.dateFormatter.date(from: last),
               let thisDate = Self.dateFormatter.date(from: date) {
                let diff = Calendar.current.dateComponents([.day], from: lastDate, to: thisDate).day ?? 0
                if diff == 1 {
                    currentStreak += 1
                } else {
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            longestStreak = max(longestStreak, currentStreak)
            lastCompletedDate = date
        } else {
            // Fail — streak broken
            currentStreak = 0
        }

        save()
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Persistence

extension BackwordStats {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Crosswords", isDirectory: true)
            .appendingPathComponent("backword_stats.json")
    }

    mutating func save() {
        let dir = Self.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    static func load() -> BackwordStats {
        guard let data = try? Data(contentsOf: fileURL),
              let stats = try? JSONDecoder().decode(BackwordStats.self, from: data)
        else { return BackwordStats() }
        return stats
    }
}
