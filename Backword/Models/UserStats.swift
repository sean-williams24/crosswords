import Foundation

struct PuzzleResult: Codable, Identifiable {
    var id: String { puzzleId }
    let puzzleId: String
    let date: Date
    let timeSeconds: Int
    let hintsUsed: Int
    var isWeekly: Bool
    /// Only a solve completed during this puzzle's own release window may
    /// extend a crossword streak. Archive solves remain valid completions.
    var completedOnReleaseDate: Bool

    init(
        puzzleId: String,
        date: Date,
        timeSeconds: Int,
        hintsUsed: Int,
        isWeekly: Bool = false,
        completedOnReleaseDate: Bool = true
    ) {
        self.puzzleId = puzzleId
        self.date = date
        self.timeSeconds = timeSeconds
        self.hintsUsed = hintsUsed
        self.isWeekly = isWeekly
        self.completedOnReleaseDate = completedOnReleaseDate
    }

    // Custom decoder so existing saved records (without isWeekly) default to false
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        puzzleId = try container.decode(String.self, forKey: .puzzleId)
        date = try container.decode(Date.self, forKey: .date)
        timeSeconds = try container.decode(Int.self, forKey: .timeSeconds)
        hintsUsed = try container.decode(Int.self, forKey: .hintsUsed)
        isWeekly = (try? container.decode(Bool.self, forKey: .isWeekly)) ?? false
        // Legacy values are corrected from their source UserProgress records
        // by StatsService. Unknown records fail closed for streak purposes.
        completedOnReleaseDate = (try? container.decode(Bool.self, forKey: .completedOnReleaseDate)) ?? false
    }
}

struct UserStats: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var totalCompleted: Int
    var averageTimeSeconds: Double
    var lastCompletedDate: Date?
    var history: [PuzzleResult]

    init() {
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalCompleted = 0
        self.averageTimeSeconds = 0
        self.lastCompletedDate = nil
        self.history = []
    }

    // The real-time streak: 0 if last completion wasn't today or yesterday
    var liveCurrentStreak: Int {
        guard let lastDate = lastCompletedDate else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        guard calendar.isDate(lastDate, inSameDayAs: today) ||
              calendar.isDate(lastDate, inSameDayAs: yesterday) else { return 0 }
        return currentStreak
    }

    mutating func recordCompletion(
        puzzleId: String,
        timeSeconds: Int,
        hintsUsed: Int,
        isWeekly: Bool = false,
        completedOnReleaseDate: Bool = true
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        let result = PuzzleResult(
            puzzleId: puzzleId,
            date: today,
            timeSeconds: timeSeconds,
            hintsUsed: hintsUsed,
            isWeekly: isWeekly,
            completedOnReleaseDate: completedOnReleaseDate
        )
        history.append(result)
        recomputeAggregates()
    }

    var formattedAverageTime: String {
        Int(averageTimeSeconds).formattedTimeHHMMSS
    }

    mutating func removeResults(puzzleIds: Set<String>) {
        guard !puzzleIds.isEmpty else { return }
        history.removeAll { puzzleIds.contains($0.puzzleId) }
        recomputeAggregates()
    }

    mutating func recomputeAggregates() {
        history.sort { $0.date < $1.date }
        totalCompleted = history.count
        averageTimeSeconds = history.isEmpty
            ? 0
            : Double(history.reduce(0) { $0 + $1.timeSeconds }) / Double(history.count)

        let calendar = Calendar.current
        let dailyDates = filteredHistory(isWeekly: false)
            .filter(\.completedOnReleaseDate)
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()

        guard let lastDate = dailyDates.last else {
            currentStreak = 0
            longestStreak = 0
            lastCompletedDate = nil
            return
        }

        lastCompletedDate = lastDate
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        if calendar.isDate(lastDate, inSameDayAs: today) || calendar.isDate(lastDate, inSameDayAs: yesterday) {
            var streak = 1
            for i in stride(from: dailyDates.count - 1, through: 1, by: -1) {
                let gap = calendar.dateComponents([.day], from: dailyDates[i - 1], to: dailyDates[i]).day ?? Int.max
                if gap <= 1 { streak += 1 } else { break }
            }
            currentStreak = streak
        } else {
            currentStreak = 0
        }

        var longest = 1
        var current = 1
        for i in 1..<dailyDates.count {
            let gap = calendar.dateComponents([.day], from: dailyDates[i - 1], to: dailyDates[i]).day ?? Int.max
            if gap <= 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        longestStreak = longest
    }

    // MARK: - Per-type filtered helpers

    func filteredHistory(isWeekly: Bool) -> [PuzzleResult] {
        history.filter { $0.isWeekly == isWeekly }
    }

    func totalCompleted(isWeekly: Bool) -> Int {
        filteredHistory(isWeekly: isWeekly).count
    }

    func formattedAverageTime(isWeekly: Bool) -> String {
        let h = filteredHistory(isWeekly: isWeekly)
        guard !h.isEmpty else { return "–" }
        let avg = Double(h.reduce(0) { $0 + $1.timeSeconds }) / Double(h.count)
        return Int(avg).formattedTimeHHMMSS
    }

    /// Current streak from the filtered history.
    /// Daily = consecutive calendar days; weekly = consecutive entries ≤8 days apart.
    func currentStreak(isWeekly: Bool) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let maxGap = isWeekly ? 8 : 1
        let dates = filteredHistory(isWeekly: isWeekly)
            .filter(\.completedOnReleaseDate)
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()
        guard let last = dates.last else { return 0 }
        let daysSinceLast = calendar.dateComponents([.day], from: last, to: today).day ?? Int.max
        guard daysSinceLast <= maxGap else { return 0 }
        var streak = 1
        for i in stride(from: dates.count - 1, through: 1, by: -1) {
            let gap = calendar.dateComponents([.day], from: dates[i - 1], to: dates[i]).day ?? Int.max
            if gap <= maxGap { streak += 1 } else { break }
        }
        return streak
    }

    func longestStreak(isWeekly: Bool) -> Int {
        let calendar = Calendar.current
        let maxGap = isWeekly ? 8 : 1
        let dates = filteredHistory(isWeekly: isWeekly)
            .filter(\.completedOnReleaseDate)
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()
        guard !dates.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<dates.count {
            let gap = calendar.dateComponents([.day], from: dates[i - 1], to: dates[i]).day ?? Int.max
            if gap <= maxGap {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}
