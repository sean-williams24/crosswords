import Foundation

//final class BackwordViewModel {
//    
//}

@MainActor
final class BackwordService: ObservableObject {
    @Published var todaysWord: BackwordWord?
    @Published var isLoading = false
//    @Published var errorMessage: String?

    private let cache = CacheService()
    private let apiClient: SupabaseClient
    private let dateFormatting = DateFormatting()
    private let baseURL = "https://cmvzqtpvzobdnnjpvyfi.supabase.co"
    private let apiKey = "sb_publishable_Kj4RZqeTrOAXeOhRVdluVA_EFEOGveT"
    private var lastFetchedDate: String?

    init(apiClient: SupabaseClient = SupabaseClient()) {
        self.apiClient = apiClient
        Task { await loadTodaysWord() }
    }

    private var today: String {
        dateFormatting.todayString()
    }

    /// Re-fetches only when the calendar date has changed since last fetch.
    /// Pass `force: true` to re-fetch unconditionally (e.g. after a debug reset).
    func refreshIfNeeded(force: Bool = false) async {
        guard force || today != lastFetchedDate || todaysWord == nil else { return }
        await loadTodaysWord()
    }

    private func loadTodaysWord() async {
        isLoading = true
//        errorMessage = nil
        defer { isLoading = false }

        if let word = cache.loadBackword(for: today) {
            todaysWord = word
            lastFetchedDate = today
            return
        }

        do {
            let word = try await apiClient.fetchFromSupabase()
            todaysWord = word
            cache.saveBackword(word, for: today)
            lastFetchedDate = today
        } catch {
//            errorMessage = "Failed to load today's word. Please try again."
            print("Supabase fetch error: \(error)")
        }
    }

    func purgeCache() async {
        cache.clearBackword(for: today)
        todaysWord = nil
        lastFetchedDate = nil
        await loadTodaysWord()
    }

    // MARK: - Supabase

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

//    private func fetchFromSupabase() async throws -> BackwordWord? {
//        let urlString = "\(baseURL)/rest/v1/backword_words?date=lte.\(today)&select=*&order=date.desc&limit=1"
//        guard let url = URL(string: urlString) else { return nil }
//
//        var request = URLRequest(url: url)
//        request.setValue(apiKey, forHTTPHeaderField: "apikey")
//        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
//        request.setValue("application/json", forHTTPHeaderField: "Accept")
//
//        let (data, response) = try await URLSession.shared.data(for: request)
//
//        guard let httpResponse = response as? HTTPURLResponse,
//              (200...299).contains(httpResponse.statusCode) else {
//            return nil
//        }
//
//        let rows = try decoder.decode([SupabaseBackwordRow].self, from: data)
//        return rows.first?.toBackwordWord
//    }

    // MARK: - Archive

    func fetchArchive() async throws -> [BackwordWord] {
        try await apiClient.fetchArchive()
    }
//        let urlString = "\(baseURL)/rest/v1/backword_words?date=lte.\(today)&select=*&order=date.desc&limit=90"
//        guard let url = URL(string: urlString) else { return [] }
//
//        var request = URLRequest(url: url)
//        request.setValue(apiKey, forHTTPHeaderField: "apikey")
//        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
//        request.setValue("application/json", forHTTPHeaderField: "Accept")
//
//        let (data, response) = try await URLSession.shared.data(for: request)
//        guard let httpResponse = response as? HTTPURLResponse,
//              (200...299).contains(httpResponse.statusCode) else { return [] }
//
//        let rows = try decoder.decode([BackwordRow].self, from: data)
//        return rows.map { $0.toBackwordWord }
//    }
}

// MARK: - Supabase Response Model

private struct SupabaseBackwordRow: Codable {
    let id: String
    let date: String
    let wordData: PartialWordData

    var toBackwordWord: BackwordWord {
        BackwordWord(id: id, date: date, word: wordData.word, category: wordData.category, definition: wordData.definition)
    }

    struct PartialWordData: Codable {
        let word: String
        let category: String
        let definition: String
    }
}
