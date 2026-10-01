import Foundation

@MainActor
protocol ArchiveDataProviding {
    func availableMonths(for type: ArchiveGameType, policy: ArchiveLoadPolicy) async -> [ArchiveMonth]
    func loadMonth(_ month: ArchiveMonth, for type: ArchiveGameType, policy: ArchiveLoadPolicy) async -> ArchiveMonthContent
}

enum ArchiveLoadPolicy {
    case cacheFirst
    case networkFirst
}

@MainActor
final class ArchiveDataSource: ArchiveDataProviding {
    private let puzzleService: PuzzleService
    private let backwordService: BackwordService
    private let midwordService: MidwordService
    private let cache: CacheService

    init(
        puzzleService: PuzzleService,
        backwordService: BackwordService? = nil,
        midwordService: MidwordService? = nil,
        cache: CacheService = CacheService()
    ) {
        self.puzzleService = puzzleService
        self.backwordService = backwordService ?? BackwordService(loadOnInit: false)
        self.midwordService = midwordService ?? MidwordService()
        self.cache = cache
    }

    func availableMonths(for type: ArchiveGameType, policy: ArchiveLoadPolicy = .networkFirst) async -> [ArchiveMonth] {
        if policy == .cacheFirst, let cachedMonths = cache.loadArchiveMonths(for: type), !cachedMonths.isEmpty {
            return cachedMonths
        }

        if let networkMonths = try? await fetchMonths(for: type) {
            cache.saveArchiveMonths(networkMonths, for: type)
            return networkMonths
        }

        return cache.loadArchiveMonths(for: type) ?? []
    }

    func loadMonth(
        _ month: ArchiveMonth,
        for type: ArchiveGameType,
        policy: ArchiveLoadPolicy = .networkFirst
    ) async -> ArchiveMonthContent {
        if policy == .cacheFirst {
            let cached = cachedMonth(month, for: type)
            if !cached.isEmpty(for: type) {
                return cached
            }
        }

        if let networkContent = try? await fetchMonth(month, for: type) {
            save(networkContent, month: month, type: type)
            return networkContent
        }

        return cachedMonth(month, for: type)
    }

    func prefetchCurrentMonth() async {
        let releaseCalendar = ContentReleaseCalendar()
        let currentBackwordMonth = releaseCalendar.month(for: .backword)
        let currentMidwordMonth = releaseCalendar.month(for: .backword)
        let currentDailyMonth = releaseCalendar.month(for: .daily)
        let currentWeeklyMonth = releaseCalendar.month(for: .weekly)

        async let backwordMonths = availableMonths(for: .backword, policy: .networkFirst)
        async let midwordMonths = availableMonths(for: .midword, policy: .networkFirst)
        async let dailyMonths = availableMonths(for: .daily, policy: .networkFirst)
        async let weeklyMonths = availableMonths(for: .weekly, policy: .networkFirst)
        _ = await (backwordMonths, midwordMonths, dailyMonths, weeklyMonths)

        async let backwordContent = loadMonth(currentBackwordMonth, for: .backword, policy: .networkFirst)
        async let midwordContent = loadMonth(currentMidwordMonth, for: .midword, policy: .networkFirst)
        async let dailyContent = loadMonth(currentDailyMonth, for: .daily, policy: .networkFirst)
        async let weeklyContent = loadMonth(currentWeeklyMonth, for: .weekly, policy: .networkFirst)
        _ = await (backwordContent, midwordContent, dailyContent, weeklyContent)
    }

    private func fetchMonths(for type: ArchiveGameType) async throws -> [ArchiveMonth] {
        switch type {
        case .backword:
            return try await backwordService.fetchArchiveMonths()
        case .midword:
            return try await midwordService.fetchArchiveMonths()
        case .daily:
            return try await puzzleService.fetchArchiveMonths()
        case .weekly:
            return try await puzzleService.fetchWeeklyArchiveMonths()
        }
    }

    private func fetchMonth(_ month: ArchiveMonth, for type: ArchiveGameType) async throws -> ArchiveMonthContent {
        switch type {
        case .backword:
            return ArchiveMonthContent(backwordWords: try await backwordService.fetchBackwords(for: month))
        case .midword:
            return ArchiveMonthContent(midwordPuzzles: try await midwordService.fetchPuzzles(for: month))
        case .daily:
            return ArchiveMonthContent(dailyPuzzles: try await puzzleService.fetchPuzzles(for: month))
        case .weekly:
            return ArchiveMonthContent(weeklyPuzzles: try await puzzleService.fetchWeeklyPuzzles(for: month))
        }
    }

    private func save(_ content: ArchiveMonthContent, month: ArchiveMonth, type: ArchiveGameType) {
        switch type {
        case .backword:
            cache.saveBackwordArchive(content.backwordWords, for: month)
        case .midword:
            cache.saveMidwordArchive(content.midwordPuzzles, for: month)
        case .daily:
            cache.saveDailyArchive(content.dailyPuzzles, for: month)
        case .weekly:
            cache.saveWeeklyArchive(content.weeklyPuzzles, for: month)
        }
    }

    private func cachedMonth(_ month: ArchiveMonth, for type: ArchiveGameType) -> ArchiveMonthContent {
        switch type {
        case .backword:
            return ArchiveMonthContent(backwordWords: cache.loadBackwordArchive(for: month) ?? [])
        case .midword:
            return ArchiveMonthContent(midwordPuzzles: cache.loadMidwordArchive(for: month) ?? [])
        case .daily:
            return ArchiveMonthContent(dailyPuzzles: cache.loadDailyArchive(for: month) ?? [])
        case .weekly:
            return ArchiveMonthContent(weeklyPuzzles: cache.loadWeeklyArchive(for: month) ?? [])
        }
    }
}
