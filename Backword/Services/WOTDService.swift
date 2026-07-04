import Foundation

@MainActor
final class WOTDService: ObservableObject {

    @Published var todaysWord: WordOfTheDay?
    private let cache = CacheService()
    private let dateFormatting = DateFormatting()
    private let baseURL = Secrets.supabaseURL
    private let apiKey = Secrets.supabaseAnonKey
    private let supabaseFetcher: ((String) async throws -> WordOfTheDay?)?
    private let fallbackWordProvider: (() -> WordOfTheDay?)?

    /// The date string (yyyy-MM-dd) we last fetched for
    private var lastFetchedDate: String?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private var today: String {
        dateFormatting.todayString()
    }

    init(
        loadOnInit: Bool = true,
        supabaseFetcher: ((String) async throws -> WordOfTheDay?)? = nil,
        fallbackWordProvider: (() -> WordOfTheDay?)? = nil
    ) {
        self.supabaseFetcher = supabaseFetcher
        self.fallbackWordProvider = fallbackWordProvider
        if loadOnInit {
            Task { await loadTodaysWord() }
        }
    }

    /// Re-fetches only when the calendar date has changed since last fetch.
    func refreshIfNeeded() async {
        guard today != lastFetchedDate else { return }
        await loadTodaysWord()
    }

    private func loadTodaysWord() async {
        let requestedDate = today

        if let word = cache.loadWOTD(for: requestedDate) {
            todaysWord = word
            lastFetchedDate = requestedDate
            return
        }

        if let word = try? await fetchWord(for: requestedDate) {
            todaysWord = word
            cache.saveWOTD(word, for: requestedDate)
            lastFetchedDate = requestedDate
            return
        }

        // Fall back to local bundle, but keep the date retryable so a later
        // Supabase policy/network fix can replace it with the real daily row.
        todaysWord = loadFromBundle()
    }

    // MARK: - Supabase

    private func fetchWord(for date: String) async throws -> WordOfTheDay? {
        if let supabaseFetcher {
            return try await supabaseFetcher(date)
        }

        return try await fetchFromSupabase(for: date)
    }

    private func fetchFromSupabase(for date: String) async throws -> WordOfTheDay? {
        guard let url = Self.supabaseURL(baseURL: baseURL, date: date) else { return nil }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return nil
        }

        let rows = try decoder.decode([SupabaseWOTD].self, from: data)
        return rows.first?.wordData
    }

    func purgeCache() async {
        cache.clearWOTD(for: today)
        todaysWord = nil
        lastFetchedDate = nil
        await loadTodaysWord()
    }

    // MARK: - Local Fallback

    private func loadFromBundle() -> WordOfTheDay? {
        if let fallbackWordProvider {
            return fallbackWordProvider()
        }

        guard let url = Bundle.main.url(forResource: "wotd_bank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([WordOfTheDay].self, from: data),
              !words.isEmpty
        else { return nil }

        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let dayHash = (components.year ?? 0) * 10000 + (components.month ?? 0) * 100 + (components.day ?? 0)
        return words[abs(dayHash) % words.count]
    }

    // MARK: - Helpers

    nonisolated static func supabaseURL(baseURL: String, date: String) -> URL? {
        URL(string: "\(baseURL)/rest/v1/words_of_the_day?date=eq.\(date)&select=*&limit=1")
    }

}

// MARK: - Supabase Response Model

private struct SupabaseWOTD: Codable {
    let id: String
    let date: String
    let wordData: WordOfTheDay
}
