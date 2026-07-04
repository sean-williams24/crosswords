import Foundation

@MainActor
final class BackwordService: ObservableObject {
    @Published var todaysWord: BackwordWord?
    @Published var isLoading = false

    private let cache = CacheService()
    private let apiClient: SupabaseClientProtocol
    private let dateFormatting = DateFormatting()
    private var lastFetchedDate: String?

    init(apiClient: SupabaseClientProtocol = SupabaseClient(), loadOnInit: Bool = true) {
        self.apiClient = apiClient
        if loadOnInit {
            Task { await loadTodaysWord() }
        }
    }

    private var today: String {
        dateFormatting.todayString()
    }

    /// Re-fetches only when the calendar date has changed since last fetch.
    /// Pass `force: true` to re-fetch unconditionally (e.g. after a debug reset).
    func refreshIfNeeded(force: Bool = false) async {
        guard force || today != lastFetchedDate else { return }
        await loadTodaysWord()
    }

    func purgeCache() async {
        cache.clearBackword(for: today)
        todaysWord = nil
        lastFetchedDate = nil
        await loadTodaysWord()
    }

    func fetchArchive() async throws -> [BackwordWord] {
        try await apiClient.fetchBackwordArchive()
    }

    func fetchArchiveMonths() async throws -> [ArchiveMonth] {
        try await apiClient.fetchBackwordArchiveMonths()
    }

    func fetchBackwords(for month: ArchiveMonth) async throws -> [BackwordWord] {
        let words = try await apiClient.fetchBackwords(for: month)
        words.forEach { cache.saveBackword($0, for: $0.date) }
        return words
    }

    private func loadTodaysWord() async {
        let requestedDate = today
        isLoading = true
        defer { isLoading = false }

        if let word = cache.loadBackword(for: requestedDate) {
            todaysWord = word
            lastFetchedDate = requestedDate
            return
        }

        do {
            let word = try await apiClient.fetchTodaysBackword()
            todaysWord = word
            cache.saveBackword(word, for: requestedDate)
            lastFetchedDate = requestedDate
        } catch {
            todaysWord = nil
            lastFetchedDate = requestedDate
            print("Supabase fetch error: \(error)")
        }
    }

}
