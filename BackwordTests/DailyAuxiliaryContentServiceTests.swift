import Foundation
import Testing
@testable import Backword

@Suite("Daily Auxiliary Content Service Tests")
struct DailyAuxiliaryContentServiceTests {

    @MainActor
    @Test("Backword failure is not refetched until forced or date changes")
    func backwordFailureIsNotRefetchedUntilForcedOrDateChanges() async {
        CacheService().clearBackword(for: DateFormatting().todayString())
        let client = FailingBackwordClient()
        let service = BackwordService(apiClient: client, loadOnInit: false)

        await service.refreshIfNeeded()
        await service.refreshIfNeeded()

        #expect(client.fetchTodayCallCount == 1)
        #expect(service.todaysWord == nil)
        #expect(service.isLoading == false)

        await service.refreshIfNeeded(force: true)

        #expect(client.fetchTodayCallCount == 2)
    }

    @Test("WOTD Supabase URL requests the exact local content date")
    func wotdSupabaseURLRequestsExactLocalContentDate() throws {
        let url = try #require(WOTDService.supabaseURL(
            baseURL: "https://example.supabase.co",
            date: "2026-07-05"
        ))

        #expect(url.absoluteString == "https://example.supabase.co/rest/v1/words_of_the_day?date=eq.2026-07-05&select=*&limit=1")
    }

    @MainActor
    @Test("WOTD fallback remains retryable for the same date")
    func wotdFallbackRemainsRetryableForTheSameDate() async {
        CacheService().clearWOTD(for: DateFormatting().todayString())
        let fallback = Self.word("fallback")
        let remote = Self.word("remote")
        var fetchCallCount = 0
        let service = WOTDService(
            loadOnInit: false,
            supabaseFetcher: { _ in
                fetchCallCount += 1
                if fetchCallCount == 1 {
                    throw TestError.missingContent
                }
                return remote
            },
            fallbackWordProvider: { fallback }
        )

        await service.refreshIfNeeded()
        #expect(fetchCallCount == 1)
        #expect(service.todaysWord?.word == "fallback")

        await service.refreshIfNeeded()
        #expect(fetchCallCount == 2)
        #expect(service.todaysWord?.word == "remote")
    }

    @Test("WOTD cache ignores legacy entries without a matching date envelope")
    func wotdCacheIgnoresLegacyEntriesWithoutMatchingDateEnvelope() throws {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let cache = CacheService(cacheDirectory: cacheDirectory)
        let date = "2026-07-05"
        let legacyWord = Self.word("legacy")
        let legacyData = try JSONEncoder().encode(legacyWord)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try legacyData.write(to: cacheDirectory.appendingPathComponent("wotd\(date).json"))

        #expect(cache.loadWOTD(for: date) == nil)

        cache.saveWOTD(Self.word("remote"), for: date)
        #expect(cache.loadWOTD(for: date)?.word == "remote")
    }

    private static func word(_ word: String) -> WordOfTheDay {
        WordOfTheDay(
            word: word,
            pronunciation: "",
            partOfSpeech: "noun",
            definition: "",
            etymology: "",
            synonyms: [],
            exampleSentence: ""
        )
    }
}

private final class FailingBackwordClient: SupabaseClientProtocol {
    var fetchTodayCallCount = 0

    func fetchTodaysBackword() async throws -> BackwordWord {
        fetchTodayCallCount += 1
        throw TestError.missingContent
    }

    func fetchBackwordArchive() async throws -> [BackwordWord] {
        []
    }

    func fetchBackwordArchiveMonths() async throws -> [ArchiveMonth] {
        []
    }

    func fetchBackwords(for month: ArchiveMonth) async throws -> [BackwordWord] {
        []
    }

}

private enum TestError: Error {
    case missingContent
}
