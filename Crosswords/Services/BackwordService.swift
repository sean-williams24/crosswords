import Foundation

@MainActor
final class BackwordService: ObservableObject {

    @Published var todaysWord: BackwordWord?

    // Supabase config (same project as PuzzleService)
    private let baseURL = "https://cmvzqtpvzobdnnjpvyfi.supabase.co"
    private let apiKey = "sb_publishable_Kj4RZqeTrOAXeOhRVdluVA_EFEOGveT"

    /// The date string (yyyy-MM-dd) we last fetched for
    private var lastFetchedDate: String?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init() {
        Task { await loadTodaysWord() }
    }

    /// Re-fetches only when the calendar date has changed since last fetch.
    func refreshIfNeeded() async {
        let today = Self.dateFormatter.string(from: Date())
        guard today != lastFetchedDate else { return }
        await loadTodaysWord()
    }

    private func loadTodaysWord() async {
        lastFetchedDate = Self.dateFormatter.string(from: Date())
        if let word = try? await fetchFromSupabase() {
            todaysWord = word
            return
        }
        todaysWord = loadFromBundle()
    }

    // MARK: - Supabase

    private func fetchFromSupabase() async throws -> BackwordWord? {
        let today = Self.dateFormatter.string(from: Date())
        let urlString = "\(baseURL)/rest/v1/backword_words?date=lte.\(today)&select=*&order=date.desc&limit=1"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return nil
        }

        let rows = try decoder.decode([SupabaseBackwordRow].self, from: data)
        return rows.first?.toBackwordWord
    }

    // MARK: - Local Fallback

    private func loadFromBundle() -> BackwordWord? {
        guard let url = Bundle.main.url(forResource: "backword_bank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([BackwordWord].self, from: data),
              !words.isEmpty
        else { return nil }

        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let dayHash = (components.year ?? 0) * 10000 + (components.month ?? 0) * 100 + (components.day ?? 0)
        return words[abs(dayHash) % words.count]
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

// MARK: - Supabase Response Model

private struct SupabaseBackwordRow: Codable {
    let id: String
    let date: String
    let wordData: PartialWordData

    var toBackwordWord: BackwordWord {
        BackwordWord(date: date, word: wordData.word, category: wordData.category, definition: wordData.definition)
    }

    struct PartialWordData: Codable {
        let word: String
        let category: String
        let definition: String
    }
}
