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
    case novice, scribe, linguist, grandmaster, virtuoso

    var displayName: String {
        switch self {
        case .novice:     return "Novice"
        case .scribe:      return "Scribe"
        case .linguist:    return "Linguist"
        case .grandmaster: return "Grandmaster"
        case .virtuoso:    return "Virtuoso"
        }
    }

    var color: Color {
        switch self {
        case .novice:     return Color(.systemGray)
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
        case .novice:     return 0.0
        case .scribe:      return 0.2
        case .linguist:    return 0.5
        case .grandmaster: return 0.75
        case .virtuoso:    return 0.9
        }
    }

    var nextThreshold: Double {
        switch self {
        case .novice:     return 0.2
        case .scribe:      return 0.5
        case .linguist:    return 0.75
        case .grandmaster: return 0.9
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
        let range = Self.windowDateRange()
        return dailyScores.filter { $0.date >= range.cutoff && $0.date <= range.today }
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
        return RatingTier.allCases.reversed().first { $0.threshold <= f } ?? .novice
    }

    private func scoreFor(_ day: DailyScore, isPro: Bool) -> Int {
        Self.clampScore(day.dailyCrossword)
            + (isPro ? Self.clampScore(day.weeklyCrossword ?? 0) : 0)
            + Self.clampScore(day.backword)
    }

    // MARK: - Mutation

    mutating func upsertDailyCrossword(score: Int, date: String) {
        upsert(date: date) { $0.dailyCrossword = Self.clampScore(score) }
    }

    mutating func upsertWeeklyCrossword(score: Int, date: String) {
        upsert(date: date) { $0.weeklyCrossword = Self.clampScore(score) }
    }

    mutating func upsertBackword(score: Int, date: String) {
        upsert(date: date) { $0.backword = Self.clampScore(score) }
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
        normalize()
    }

    mutating func normalize() {
        let range = Self.windowDateRange()
        dailyScores = dailyScores
            .filter { $0.date >= range.cutoff && $0.date <= range.today }
            .reduce(into: [String: DailyScore]()) { scoresByDate, day in
                let normalized = Self.normalized(day)
                guard var existing = scoresByDate[normalized.date] else {
                    scoresByDate[normalized.date] = normalized
                    return
                }

                existing.dailyCrossword = max(existing.dailyCrossword, normalized.dailyCrossword)
                existing.backword = max(existing.backword, normalized.backword)
                switch (existing.weeklyCrossword, normalized.weeklyCrossword) {
                case let (existingScore?, normalizedScore?):
                    existing.weeklyCrossword = max(existingScore, normalizedScore)
                case (nil, let normalizedScore?):
                    existing.weeklyCrossword = normalizedScore
                default:
                    break
                }
                scoresByDate[normalized.date] = existing
            }
            .values
            .sorted { $0.date > $1.date }
    }

    private static func normalized(_ day: DailyScore) -> DailyScore {
        DailyScore(
            date: day.date,
            dailyCrossword: clampScore(day.dailyCrossword),
            weeklyCrossword: day.weeklyCrossword.map(clampScore),
            backword: clampScore(day.backword)
        )
    }

    private static func clampScore(_ score: Int) -> Int {
        min(max(score, 0), 5)
    }

    static func windowDateRange(
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> (cutoff: String, today: String) {
        let releaseCalendar = ContentReleaseCalendar(now: now, calendar: calendar)
        let cutoff = releaseCalendar.dailyDateString(offsetByDays: -(windowDays - 1)) ?? releaseCalendar.dailyDateString
        return (cutoff, releaseCalendar.dailyDateString)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
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
