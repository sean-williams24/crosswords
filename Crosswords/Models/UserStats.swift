import Foundation

struct PuzzleResult: Codable, Identifiable {
    var id: String { puzzleId }
    let puzzleId: String
    let date: Date
    let timeSeconds: Int
    let hintsUsed: Int
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

    mutating func recordCompletion(puzzleId: String, timeSeconds: Int, hintsUsed: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let result = PuzzleResult(
            puzzleId: puzzleId,
            date: today,
            timeSeconds: timeSeconds,
            hintsUsed: hintsUsed
        )
        history.append(result)
        totalCompleted += 1

        // Update average time
        let totalTime = averageTimeSeconds * Double(totalCompleted - 1) + Double(timeSeconds)
        averageTimeSeconds = totalTime / Double(totalCompleted)

        // Update streak — use liveCurrentStreak so a multi-day gap resets correctly
        if let lastDate = lastCompletedDate {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            if Calendar.current.isDate(lastDate, inSameDayAs: yesterday) {
                currentStreak = liveCurrentStreak + 1
            } else if !Calendar.current.isDate(lastDate, inSameDayAs: today) {
                currentStreak = 1
            }
            // Same day → don't change streak
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        lastCompletedDate = today
    }

    var formattedAverageTime: String {
        let seconds = Int(averageTimeSeconds)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}
