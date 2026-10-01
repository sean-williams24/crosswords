import Foundation
import Supabase

@MainActor
final class MidwordService: ObservableObject {
    @Published private(set) var todaysPuzzle: MidwordPuzzle?
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false

    private let client: Supabase.SupabaseClient
    private var loadedDate: String?

    init(client: Supabase.SupabaseClient = SupabaseClient.shared.client) {
        self.client = client
    }

    func refreshIfNeeded(force: Bool = false) async {
        let today = ContentReleaseCalendar().dailyDateString
        guard force || today != loadedDate else { return }
        loadedDate = today
        isLoading = true
        defer { isLoading = false }

        if !force, let cached = Self.loadCached(date: today) {
            todaysPuzzle = cached
            loadFailed = false
            return
        }

        do {
            let row: MidwordRow = try await client.from("midword_puzzles")
                .select().eq("date", value: today).single().execute().value
            guard row.puzzle.isValid else { throw MidwordServiceError.invalidPuzzle }
            todaysPuzzle = row.puzzle
            loadFailed = false
            Self.cache(row.puzzle)
        } catch {
            todaysPuzzle = Self.loadCached(date: today)
            loadFailed = todaysPuzzle == nil
        }
    }

    func fetchArchive() async throws -> [MidwordPuzzle] {
        let rows: [MidwordRow] = try await client.from("midword_puzzles")
            .select().lte("date", value: ContentReleaseCalendar().dailyDateString)
            .order("date", ascending: false).execute().value
        return rows.map(\.puzzle).filter(\.isValid)
    }

    func fetchArchiveMonths() async throws -> [ArchiveMonth] {
        let rows: [MidwordDateRow] = try await client.from("midword_puzzles")
            .select("date").lte("date", value: ContentReleaseCalendar().dailyDateString)
            .order("date", ascending: false).execute().value
        return Array(Set(rows.compactMap { ArchiveMonth.from(dateString: $0.date) })).sorted(by: >)
    }

    func fetchPuzzles(for month: ArchiveMonth) async throws -> [MidwordPuzzle] {
        let rows: [MidwordRow] = try await client.from("midword_puzzles")
            .select().gte("date", value: month.dateRange().lowerBound)
            .lte("date", value: min(month.dateRange().upperBound, ContentReleaseCalendar().dailyDateString))
            .order("date", ascending: false).execute().value
        return rows.map(\.puzzle).filter(\.isValid)
    }

    private static func cacheURL(date: String) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("midword_\(date).json")
    }

    private static func loadCached(date: String) -> MidwordPuzzle? {
        guard let data = try? Data(contentsOf: cacheURL(date: date)),
              let puzzle = try? JSONDecoder().decode(MidwordPuzzle.self, from: data),
              puzzle.isValid else { return nil }
        return puzzle
    }

    private static func cache(_ puzzle: MidwordPuzzle) {
        guard let data = try? JSONEncoder().encode(puzzle) else { return }
        try? data.write(to: cacheURL(date: puzzle.date), options: .atomic)
    }
}

private enum MidwordServiceError: Error { case invalidPuzzle }
private struct MidwordDateRow: Decodable { let date: String }
