import Foundation

@MainActor
final class PuzzleService: ObservableObject {

    // MARK: - Configuration

    /// Set these to your Supabase project values
    private let baseURL: String = "https://cmvzqtpvzobdnnjpvyfi.supabase.co"
    private let apiKey: String = "sb_publishable_Kj4RZqeTrOAXeOhRVdluVA_EFEOGveT"

    private let cache = CacheService()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Public API

    func fetchTodaysPuzzle() async throws -> Puzzle {
        let today = todayString()

        // Try cache first
        if let cached = cache.loadPuzzle(for: today) {
            return cached
        }

        // Fetch from network
        let puzzle = try await fetchPuzzle(date: today)
        cache.savePuzzle(puzzle, for: today)
        return puzzle
    }

    func fetchPuzzle(forDate date: String) async throws -> Puzzle {
        if let cached = cache.loadPuzzle(for: date) {
            return cached
        }
        let puzzle = try await fetchPuzzle(date: date)
        cache.savePuzzle(puzzle, for: date)
        return puzzle
    }

    /// Fetches lightweight metadata for all released puzzles (no grid data).
    func fetchArchive() async throws -> [ArchiveEntry] {
        let today = todayString()
        let urlString = "\(baseURL)/rest/v1/puzzles?date=lte.\(today)&select=id,puzzle_number,date&order=date.desc"
        guard let url = URL(string: urlString) else {
            throw PuzzleServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([ArchiveEntry].self, from: data)
    }

    func fetchWeeklyArchive() async throws -> [ArchiveEntry] {
        let today = todayString()
        let urlString = "\(baseURL)/rest/v1/weekly_puzzles?date=lte.\(today)&select=id,puzzle_number,date&order=date.desc"
        guard let url = URL(string: urlString) else {
            throw PuzzleServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode([ArchiveEntry].self, from: data)
    }

    func prefetchUpcomingPuzzles() async {
        let calendar = Calendar.current
        let today = Date()

        for dayOffset in 0...6 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let dateString = Self.dateFormatter.string(from: date)

            if cache.loadPuzzle(for: dateString) != nil { continue }

            if let puzzle = try? await fetchPuzzle(date: dateString) {
                cache.savePuzzle(puzzle, for: dateString)
            }
        }
    }

    /// Fetches the current weekly puzzle (most recent with date <= today).
    func fetchCurrentWeeklyPuzzle() async throws -> Puzzle {
        let today = todayString()

        // Try cache first
        let cacheKey = "weekly_\(today)"
        if let cached = cache.loadPuzzle(for: cacheKey) {
            return cached
        }

        let urlString = "\(baseURL)/rest/v1/weekly_puzzles?date=lte.\(today)&select=*&order=date.desc&limit=1"
        guard let url = URL(string: urlString) else {
            throw PuzzleServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PuzzleServiceError.serverError
        }

        let puzzles = try decoder.decode([SupabasePuzzle].self, from: data)
        guard let first = puzzles.first else {
            throw PuzzleServiceError.noPuzzleForDate
        }

        let puzzle = first.toPuzzle()
        cache.savePuzzle(puzzle, for: cacheKey)
        return puzzle
    }

    func fetchWeeklyPuzzle(forDate date: String) async throws -> Puzzle {
        let cacheKey = "weekly_\(date)"
        if let cached = cache.loadPuzzle(for: cacheKey) {
            return cached
        }

        let urlString = "\(baseURL)/rest/v1/weekly_puzzles?date=eq.\(date)&select=*"
        guard let url = URL(string: urlString) else {
            throw PuzzleServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PuzzleServiceError.serverError
        }

        let puzzles = try decoder.decode([SupabasePuzzle].self, from: data)
        guard let first = puzzles.first else {
            throw PuzzleServiceError.noPuzzleForDate
        }

        let puzzle = first.toPuzzle()
        cache.savePuzzle(puzzle, for: cacheKey)
        return puzzle
    }

    // MARK: - Network

    private func fetchPuzzle(date: String) async throws -> Puzzle {
        let urlString = "\(baseURL)/rest/v1/puzzles?date=eq.\(date)&select=*"
        guard let url = URL(string: urlString) else {
            throw PuzzleServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("[PuzzleService] HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            print("[PuzzleService] Body: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw PuzzleServiceError.serverError
        }

        print("[PuzzleService] Fetching date=\(date), got \(data.count) bytes")
        print("[PuzzleService] Raw: \(String(data: data, encoding: .utf8)?.prefix(500) ?? "nil")")

        // Supabase returns an array; we want the first result
        let puzzles: [SupabasePuzzle]
        do {
            puzzles = try decoder.decode([SupabasePuzzle].self, from: data)
        } catch {
            print("[PuzzleService] Decode error: \(error)")
            throw error
        }
        guard let first = puzzles.first else {
            print("[PuzzleService] Empty array — no puzzle for date '\(date)'")
            throw PuzzleServiceError.noPuzzleForDate
        }

        return first.toPuzzle()
    }

    private func todayString() -> String {
        Self.dateFormatter.string(from: Date())
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Errors

    enum PuzzleServiceError: LocalizedError {
        case invalidURL
        case serverError
        case noPuzzleForDate

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .serverError: return "Server error"
            case .noPuzzleForDate: return "No puzzle available for today"
            }
        }
    }
}

// MARK: - Archive Entry

struct ArchiveEntry: Codable, Identifiable {
    let id: String
    let puzzleNumber: Int
    let date: String
}

// MARK: - Supabase Response Model

/// Maps the Supabase row schema to our domain model
private struct SupabasePuzzle: Codable {
    let id: String
    let puzzleNumber: Int
    let date: String
    let gridData: GridData
    let clues: [Clue]

    struct GridData: Codable {
        let size: Int
        let cells: [[CellData]]
    }

    func toPuzzle() -> Puzzle {
        Puzzle(
            id: id,
            puzzleNumber: puzzleNumber,
            date: date,
            size: gridData.size,
            cells: gridData.cells,
            clues: clues
        )
    }
}
