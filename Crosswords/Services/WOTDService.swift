import Foundation

@MainActor
final class WOTDService: ObservableObject {

    @Published var todaysWord: WordOfTheDay?

    // Supabase config (same project as PuzzleService)
    private let baseURL = "https://cmvzqtpvzobdnnjpvyfi.supabase.co"
    private let apiKey = "sb_publishable_Kj4RZqeTrOAXeOhRVdluVA_EFEOGveT"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init() {
        Task { await loadTodaysWord() }
    }

    private func loadTodaysWord() async {
        // Try Supabase first
        if let word = try? await fetchFromSupabase() {
            todaysWord = word
            return
        }
        // Fall back to local bundle
        todaysWord = loadFromBundle()
    }

    // MARK: - Supabase

    private func fetchFromSupabase() async throws -> WordOfTheDay? {
        let today = Self.dateFormatter.string(from: Date())
        // Try today's word first, then fall back to the latest available
        let urlString = "\(baseURL)/rest/v1/words_of_the_day?date=lte.\(today)&select=*&order=date.desc&limit=1"
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

        let rows = try decoder.decode([SupabaseWOTD].self, from: data)
        return rows.first?.wordData
    }

    // MARK: - Local Fallback

    private func loadFromBundle() -> WordOfTheDay? {
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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

// MARK: - Supabase Response Model

private struct SupabaseWOTD: Codable {
    let id: String
    let date: String
    let wordData: WordOfTheDay
}
