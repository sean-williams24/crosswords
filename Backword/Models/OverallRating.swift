import SwiftUI

// MARK: - Daily Score

/// Recorded scores for a single calendar day across all games.
struct DailyScore: Codable {
    let date: String          // "yyyy-MM-dd"
    var dailyCrossword: Int   // 0–5
    var weeklyCrossword: Int? // 0–5, nil if not Pro or no weekly that week
    var backword: Int         // 0–5

    var total: Int { dailyCrossword + (weeklyCrossword ?? 0) + backword }
}

// MARK: - Rating Tier

enum RatingTier: CaseIterable {
    case dabbler, scribe, linguist, grandmaster, virtuoso

    var displayName: String {
        switch self {
        case .dabbler:     return "Dabbler"
        case .scribe:      return "Scribe"
        case .linguist:    return "Linguist"
        case .grandmaster: return "Grandmaster"
        case .virtuoso:    return "Virtuoso"
        }
    }

    var color: Color {
        switch self {
        case .dabbler:     return Color(.systemGray)
        case .scribe:      return Color(red: 0.4, green: 0.6, blue: 0.9)
        case .linguist:    return Color(red: 0.2, green: 0.5, blue: 0.95)
        case .grandmaster: return Color(red: 0.1, green: 0.35, blue: 0.85)
        case .virtuoso:    return Color(red: 0.85, green: 0.65, blue: 0.2)
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .virtuoso:
            return LinearGradient(
                colors: [Color(red: 0.95, green: 0.8, blue: 0.3),
                         Color(red: 0.85, green: 0.55, blue: 0.15)],
                startPoint: .leading, endPoint: .trailing
            )
        default:
            return LinearGradient(colors: [color], startPoint: .leading, endPoint: .trailing)
        }
    }

    /// Minimum fraction (0–1) of max possible points to reach this tier.
    var threshold: Double {
        switch self {
        case .dabbler:     return 0.0
        case .scribe:      return 0.2
        case .linguist:    return 0.4
        case .grandmaster: return 0.6
        case .virtuoso:    return 0.8
        }
    }

    var nextThreshold: Double {
        switch self {
        case .dabbler:     return 0.2
        case .scribe:      return 0.4
        case .linguist:    return 0.6
        case .grandmaster: return 0.8
        case .virtuoso:    return 1.0
        }
    }
}

// MARK: - Scoring Helpers

extension Int {
    /// Convert a completion percentage (0–100) to a crossword score (0–5).
    static func crosswordScore(percentComplete: Int) -> Int {
        switch percentComplete {
        case 100:      return 5
        case 75...99:  return 4
        case 50...74:  return 3
        case 25...49:  return 2
        case 1...24:   return 1
        default:       return 0
        }
    }

    /// Convert a Backword guess count to a score (0–5). nil = loss.
    static func backwordScore(guessCount: Int?) -> Int {
        guard let n = guessCount else { return 0 }
        return Swift.max(0, 6 - n) // 1→5, 2→4, 3→3, 4→2, 5→1
    }
}

// MARK: - Overall Rating

struct OverallRating: Codable {
    var dailyScores: [DailyScore] = []

    // MARK: - Rolling 14-day window

    private static let windowDays = 14

    private var window: [DailyScore] {
        let cutoff = Self.cutoffDate()
        return dailyScores.filter { $0.date >= cutoff }
    }

    func totalPoints(isPro: Bool) -> Int {
        window.reduce(0) { $0 + scoreFor($1, isPro: isPro) }
    }

    func maxPoints(isPro: Bool) -> Int {
        // Daily crossword + Backword every day = 10 pts/day
        // Pro users also get up to 2 weekly puzzles in a 14-day window = 10 pts
        let dailyMax = Self.windowDays * 5 * 2   // 140
        let weeklyMax = isPro ? 2 * 5 : 0        // 10 or 0
        return dailyMax + weeklyMax
    }

    func fraction(isPro: Bool) -> Double {
        let max = maxPoints(isPro: isPro)
        guard max > 0 else { return 0 }
        return min(Double(totalPoints(isPro: isPro)) / Double(max), 1.0)
    }

    func tier(isPro: Bool) -> RatingTier {
        let f = fraction(isPro: isPro)
        return RatingTier.allCases.reversed().first { $0.threshold <= f } ?? .dabbler
    }

    private func scoreFor(_ day: DailyScore, isPro: Bool) -> Int {
        day.dailyCrossword + (isPro ? (day.weeklyCrossword ?? 0) : 0) + day.backword
    }

    // MARK: - Mutation

    mutating func upsertDailyCrossword(score: Int, date: String) {
        upsert(date: date) { $0.dailyCrossword = score }
    }

    mutating func upsertWeeklyCrossword(score: Int, date: String) {
        upsert(date: date) { $0.weeklyCrossword = score }
    }

    mutating func upsertBackword(score: Int, date: String) {
        upsert(date: date) { $0.backword = score }
    }

    private mutating func upsert(date: String, update: (inout DailyScore) -> Void) {
        if let idx = dailyScores.firstIndex(where: { $0.date == date }) {
            update(&dailyScores[idx])
        } else {
            var entry = DailyScore(date: date, dailyCrossword: 0, weeklyCrossword: nil, backword: 0)
            update(&entry)
            dailyScores.append(entry)
        }
        trim()
    }

    mutating func trim() {
        let cutoff = Self.cutoffDate()
        dailyScores = dailyScores.filter { $0.date >= cutoff }
    }

    private static func cutoffDate() -> String {
        let cal = Calendar.current
        let cutoffDate = cal.date(byAdding: .day, value: -(windowDays - 1), to: cal.startOfDay(for: Date()))!
        return dateFormatter.string(from: cutoffDate)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

// MARK: - Persistence

extension OverallRating {
    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backword", isDirectory: true)
            .appendingPathComponent("overall_rating.json")
    }

    func save() {
        let dir = Self.fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    static func load() -> OverallRating {
        guard let data = try? Data(contentsOf: fileURL),
              var rating = try? JSONDecoder().decode(OverallRating.self, from: data)
        else { return OverallRating() }
        rating.trim()
        return rating
    }
}
