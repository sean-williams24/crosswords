import Combine
import Foundation
import OSLog

@MainActor
protocol AnagramDataSource {
    func firstPublishedPuzzle() async throws -> AnagramPuzzle?
    func puzzle(for date: String) async throws -> AnagramPuzzle?
    func puzzles(for month: ArchiveMonth, through date: String) async throws -> [AnagramPuzzle]
}

@MainActor
struct SupabaseAnagramDataSource: AnagramDataSource {
    private let client = SupabaseClient.shared.client

    func firstPublishedPuzzle() async throws -> AnagramPuzzle? {
        let rows: [AnagramPuzzleRow] = try await client.from("anagram_puzzles")
            .select().order("date", ascending: true).limit(1).execute().value
        return rows.first?.puzzle
    }

    func puzzle(for date: String) async throws -> AnagramPuzzle? {
        let row: AnagramPuzzleRow = try await client.from("anagram_puzzles")
            .select().eq("date", value: date).single().execute().value
        return row.puzzle
    }

    func puzzles(for month: ArchiveMonth, through date: String) async throws -> [AnagramPuzzle] {
        let range = month.dateRange()
        let rows: [AnagramPuzzleRow] = try await client.from("anagram_puzzles")
            .select().gte("date", value: range.lowerBound)
            .lte("date", value: min(range.upperBound, date))
            .order("date", ascending: false).execute().value
        return rows.map(\.puzzle)
    }
}

@MainActor
final class AnagramService: ObservableObject {
    @Published private(set) var todaysPuzzle: AnagramPuzzle?
    @Published private(set) var isLoading = false
    @Published private(set) var hasAttemptedLoad = false

    private let dataSource: AnagramDataSource
    private let cacheDirectory: URL
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Backword", category: "anagram")
    private var fetchedDate: String?

    init(
        dataSource: AnagramDataSource? = nil,
        cacheDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backword", isDirectory: true)
            .appendingPathComponent("anagram-content", isDirectory: true)
    ) {
        self.dataSource = dataSource ?? SupabaseAnagramDataSource()
        self.cacheDirectory = cacheDirectory
    }

    private func cachedPuzzle(for date: String) -> AnagramPuzzle? {
        let url = cacheDirectory.appendingPathComponent("\(date).json")
        guard let data = try? Data(contentsOf: url),
              let puzzle = try? JSONDecoder().decode(AnagramPuzzle.self, from: data),
              puzzle.isValid else { return nil }
        return puzzle
    }

    private func cache(_ puzzle: AnagramPuzzle) {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(puzzle) else { return }
        try? data.write(to: cacheDirectory.appendingPathComponent("\(puzzle.date).json"), options: .atomic)
    }

    func refreshIfNeeded(now: Date = Date()) async {
        let date = ContentReleaseCalendar(now: now).dailyDateString
        guard fetchedDate != date else { return }
        todaysPuzzle = cachedPuzzle(for: date)
        hasAttemptedLoad = false
        isLoading = true
        defer {
            isLoading = false
            hasAttemptedLoad = true
        }
        do {
            if let puzzle = try await dataSource.puzzle(for: date), puzzle.isValid {
                todaysPuzzle = puzzle
                cache(puzzle)
                fetchedDate = date
            }
        } catch {
            // Keep the cache visible and retry on the next refresh/foreground.
            logger.error("Anagram fetch failed for \(date, privacy: .public): \(error.localizedDescription, privacy: .private)")
        }
        if UserDefaults.standard.string(forKey: "Anagram.firstReleaseDate") == nil,
           let first = try? await dataSource.firstPublishedPuzzle(), first.isValid {
            UserDefaults.standard.set(first.date, forKey: "Anagram.firstReleaseDate")
        }
    }

    #if DEBUG
    func debugResetTodaysProgress(now: Date = Date()) {
        guard let puzzle = todaysPuzzle,
              puzzle.date == AnagramProgress.localDay(now) else { return }
        AnagramProgress.delete(date: puzzle.date)
    }
    #endif

    /// Clears cached content and leaves the loading card visible before the debug refetch.
    func purgeCache(now: Date = Date(), minimumLoadingDuration: Duration = .seconds(2)) async {
        try? FileManager.default.removeItem(at: cacheDirectory)
        todaysPuzzle = nil
        fetchedDate = nil
        hasAttemptedLoad = false
        isLoading = true
        try? await Task.sleep(for: minimumLoadingDuration)
        await refreshIfNeeded(now: now)
    }

    func fetchArchive(for month: ArchiveMonth, now: Date = Date()) async -> [AnagramPuzzle] {
        let today = AnagramProgress.localDay(now)
        let url = cacheDirectory.appendingPathComponent("archive-\(month.key).json")
        let cached = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([AnagramPuzzle].self, from: $0) } ?? []
        do {
            let puzzles = try await dataSource.puzzles(for: month, through: today)
                .filter { $0.isValid && $0.date <= today }
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(puzzles) {
                try? data.write(to: url, options: .atomic)
            }
            return puzzles
        } catch {
            return cached.filter { $0.isValid && $0.date <= today }
        }
    }

    func fetchArchiveMonths(now: Date = Date()) async -> [ArchiveMonth] {
        let today = AnagramProgress.localDay(now)
        var firstReleaseDate = UserDefaults.standard.string(forKey: "Anagram.firstReleaseDate")

        if let first = try? await dataSource.firstPublishedPuzzle(), first.isValid {
            firstReleaseDate = first.date
            UserDefaults.standard.set(first.date, forKey: "Anagram.firstReleaseDate")
        }

        guard let firstReleaseDate else { return [] }
        return Self.archiveMonths(from: firstReleaseDate, through: today)
    }

    nonisolated static func archiveMonths(from firstDate: String, through currentDate: String) -> [ArchiveMonth] {
        guard let firstMonth = ArchiveMonth.from(dateString: firstDate),
              let currentMonth = ArchiveMonth.from(dateString: currentDate),
              firstMonth <= currentMonth else { return [] }

        var result: [ArchiveMonth] = []
        var month = currentMonth
        while month >= firstMonth {
            result.append(month)
            if month.month == 1 {
                month = ArchiveMonth(year: month.year - 1, month: 12)
            } else {
                month = ArchiveMonth(year: month.year, month: month.month - 1)
            }
        }
        return result
    }
}
