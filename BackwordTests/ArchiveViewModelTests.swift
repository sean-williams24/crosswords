import Foundation
import Combine
import Testing
@testable import Backword

@Suite("Archive Month Tests")
@MainActor
struct ArchiveViewModelTests {

    @Test("Month range uses calendar month bounds")
    func monthRange() {
        let february = ArchiveMonth(year: 2024, month: 2)

        #expect(february.dateRange().lowerBound == "2024-02-01")
        #expect(february.dateRange().upperBound == "2024-02-29")
    }

    @Test("Months sort newest first for archive display")
    func monthOrdering() {
        let months = [
            ArchiveMonth(year: 2026, month: 4),
            ArchiveMonth(year: 2025, month: 12),
            ArchiveMonth(year: 2026, month: 6)
        ].sorted(by: >)

        #expect(months.map(\.key) == ["2026-06", "2026-04", "2025-12"])
    }

    @Test("Initial load fetches current month playable games")
    func initialLoadFetchesCurrentMonthGames() async {
        let currentMonth = ArchiveMonth(year: 2026, month: 6)
        let dataSource = MockArchiveDataSource(currentMonth: currentMonth)
        let viewModel = ArchiveViewModel(dataSource: dataSource, currentMonth: currentMonth)

        await viewModel.loadInitialArchive()

        #expect(viewModel.currentBackwordWords.map(\.id) == ["backword-current"])
        #expect(viewModel.currentDailyPuzzles.map(\.id) == ["daily-current"])
        #expect(viewModel.currentWeeklyPuzzles.map(\.id) == ["weekly-current"])
        #expect(dataSource.loadedMonths.contains(ArchiveMonthKey(type: .backword, month: currentMonth)))
        #expect(dataSource.loadedMonths.contains(ArchiveMonthKey(type: .daily, month: currentMonth)))
        #expect(dataSource.loadedMonths.contains(ArchiveMonthKey(type: .weekly, month: currentMonth)))
        #expect(dataSource.monthLoadPolicies.allSatisfy { $0 == .cacheFirst })
    }

    @Test("Earlier months exclude current month")
    func earlierMonthsExcludeCurrentMonth() async {
        let currentMonth = ArchiveMonth(year: 2026, month: 6)
        let previousMonth = ArchiveMonth(year: 2026, month: 5)
        let dataSource = MockArchiveDataSource(currentMonth: currentMonth, olderMonth: previousMonth)
        let viewModel = ArchiveViewModel(dataSource: dataSource, currentMonth: currentMonth)

        await viewModel.loadInitialArchive()

        #expect(viewModel.earlierMonths(for: .daily) == [previousMonth])
    }

    @Test("Initial load asks archive source for cached month indexes")
    func initialLoadUsesCachedMonthIndexes() async {
        let currentMonth = ArchiveMonth(year: 2026, month: 6)
        let dataSource = MockArchiveDataSource(currentMonth: currentMonth)
        let viewModel = ArchiveViewModel(dataSource: dataSource, currentMonth: currentMonth)

        await viewModel.loadInitialArchive()

        #expect(dataSource.availableMonthPolicies.count == 3)
        #expect(dataSource.availableMonthPolicies.allSatisfy { $0 == .cacheFirst })
    }

    @Test("Expanding older month uses network first")
    func expandingOlderMonthUsesNetworkFirst() async {
        let currentMonth = ArchiveMonth(year: 2026, month: 6)
        let previousMonth = ArchiveMonth(year: 2026, month: 5)
        let dataSource = MockArchiveDataSource(currentMonth: currentMonth, olderMonth: previousMonth)
        let viewModel = ArchiveViewModel(dataSource: dataSource, currentMonth: currentMonth)

        await viewModel.loadInitialArchive()
        await viewModel.expandOrCollapse(previousMonth, for: .daily)

        #expect(dataSource.loadPolicy(for: ArchiveMonthKey(type: .daily, month: previousMonth)) == .networkFirst)
    }

    @Test("Expanding a second month collapses the previous month in the same tab")
    func expandingSecondMonthCollapsesPreviousMonth() async {
        let currentMonth = ArchiveMonth(year: 2026, month: 6)
        let may = ArchiveMonth(year: 2026, month: 5)
        let april = ArchiveMonth(year: 2026, month: 4)
        let dataSource = MockArchiveDataSource(currentMonth: currentMonth, olderMonth: may, additionalOlderMonth: april)
        let viewModel = ArchiveViewModel(dataSource: dataSource, currentMonth: currentMonth)

        await viewModel.loadInitialArchive()
        await viewModel.expandOrCollapse(may, for: .daily)
        await viewModel.expandOrCollapse(april, for: .daily)

        #expect(viewModel.expandedMonth(for: .daily) == april)
        #expect(!viewModel.isExpanded(may, for: .daily))
    }

    @Test("Expanded month is preserved per tab")
    func expandedMonthIsPreservedPerTab() async {
        let currentMonth = ArchiveMonth(year: 2026, month: 6)
        let may = ArchiveMonth(year: 2026, month: 5)
        let april = ArchiveMonth(year: 2026, month: 4)
        let dataSource = MockArchiveDataSource(currentMonth: currentMonth, olderMonth: may, additionalOlderMonth: april)
        let viewModel = ArchiveViewModel(dataSource: dataSource, currentMonth: currentMonth)

        await viewModel.loadInitialArchive()
        await viewModel.expandOrCollapse(may, for: .daily)
        await viewModel.expandOrCollapse(april, for: .weekly)

        #expect(viewModel.expandedMonth(for: .daily) == may)
        #expect(viewModel.expandedMonth(for: .weekly) == april)
    }

    @Test("Opening archive puzzle captures newest loaded weekly as current")
    func openingArchivePuzzleCapturesNewestLoadedWeeklyAsCurrent() async {
        let currentMonth = ArchiveMonth(year: 2026, month: 6)
        let previousMonth = ArchiveMonth(year: 2026, month: 5)
        let dataSource = MockArchiveDataSource(currentMonth: currentMonth, olderMonth: previousMonth)
        let viewModel = ArchiveViewModel(dataSource: dataSource, currentMonth: currentMonth)

        await viewModel.loadInitialArchive()
        let puzzle = makePuzzle(id: "daily-archive", date: "2026-06-12")
        viewModel.openPuzzle(puzzle, type: .daily)

        #expect(viewModel.selectedPuzzle?.id == "daily-archive")
        #expect(viewModel.selectedPuzzleLaunchContext == .archive(type: .daily, currentWeeklyPuzzleId: "weekly-current"))
    }

    @Test("Switching between already loaded months publishes a view update")
    func switchingLoadedMonthsPublishesUpdate() async {
        let currentMonth = ArchiveMonth(year: 2026, month: 6)
        let may = ArchiveMonth(year: 2026, month: 5)
        let april = ArchiveMonth(year: 2026, month: 4)
        let dataSource = MockArchiveDataSource(currentMonth: currentMonth, olderMonth: may, additionalOlderMonth: april)
        let viewModel = ArchiveViewModel(dataSource: dataSource, currentMonth: currentMonth)
        var updateCount = 0
        let cancellable = viewModel.objectWillChange.sink {
            updateCount += 1
        }

        await viewModel.loadInitialArchive()
        await viewModel.expandOrCollapse(may, for: .daily)
        await viewModel.expandOrCollapse(april, for: .daily)
        let updatesBeforeSwitchingBack = updateCount
        await viewModel.expandOrCollapse(may, for: .daily)

        #expect(viewModel.expandedMonth(for: .daily) == may)
        #expect(updateCount > updatesBeforeSwitchingBack)
        cancellable.cancel()
    }

    @Test("Monthly cache stores playable game payloads")
    func monthlyCacheStoresPlayablePayloads() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArchiveViewModelTests-\(UUID().uuidString)", isDirectory: true)
        let cache = CacheService(cacheDirectory: directory)
        let month = ArchiveMonth(year: 2026, month: 6)
        let daily = makePuzzle(id: "cached-daily", date: "2026-06-13")
        let weekly = makePuzzle(id: "cached-weekly", date: "2026-06-07")
        let backword = makeBackword(id: "cached-backword", date: "2026-06-13")

        cache.saveDailyArchive([daily], for: month)
        cache.saveWeeklyArchive([weekly], for: month)
        cache.saveBackwordArchive([backword], for: month)

        #expect(cache.loadDailyArchive(for: month)?.map(\.id) == ["cached-daily"])
        #expect(cache.loadWeeklyArchive(for: month)?.map(\.id) == ["cached-weekly"])
        #expect(cache.loadBackwordArchive(for: month)?.map(\.id) == ["cached-backword"])
    }
}

@MainActor
private final class MockArchiveDataSource: ArchiveDataProviding {
    private let months: [ArchiveMonth]
    private let currentMonth: ArchiveMonth
    private var content: [ArchiveMonthKey: ArchiveMonthContent] = [:]

    private(set) var loadedMonths: Set<ArchiveMonthKey> = []
    private(set) var availableMonthPolicies: [ArchiveLoadPolicy] = []
    private(set) var loadedMonthPolicies: [ArchiveMonthKey: ArchiveLoadPolicy] = [:]

    var monthLoadPolicies: [ArchiveLoadPolicy] {
        Array(loadedMonthPolicies.values)
    }

    init(
        currentMonth: ArchiveMonth,
        olderMonth: ArchiveMonth = ArchiveMonth(year: 2026, month: 5),
        additionalOlderMonth: ArchiveMonth? = nil
    ) {
        self.currentMonth = currentMonth
        self.months = ([currentMonth, olderMonth] + [additionalOlderMonth].compactMap { $0 }).sorted(by: >)

        content[ArchiveMonthKey(type: .backword, month: currentMonth)] = ArchiveMonthContent(
            backwordWords: [makeBackword(id: "backword-current", date: "2026-06-13")]
        )
        content[ArchiveMonthKey(type: .daily, month: currentMonth)] = ArchiveMonthContent(
            dailyPuzzles: [makePuzzle(id: "daily-current", date: "2026-06-13")]
        )
        content[ArchiveMonthKey(type: .weekly, month: currentMonth)] = ArchiveMonthContent(
            weeklyPuzzles: [makePuzzle(id: "weekly-current", date: "2026-06-07")]
        )

        for month in months where month != currentMonth {
            content[ArchiveMonthKey(type: .daily, month: month)] = ArchiveMonthContent(
                dailyPuzzles: [makePuzzle(id: "daily-\(month.key)", date: month.startDateString)]
            )
            content[ArchiveMonthKey(type: .weekly, month: month)] = ArchiveMonthContent(
                weeklyPuzzles: [makePuzzle(id: "weekly-\(month.key)", date: month.startDateString)]
            )
            content[ArchiveMonthKey(type: .backword, month: month)] = ArchiveMonthContent(
                backwordWords: [makeBackword(id: "backword-\(month.key)", date: month.startDateString)]
            )
        }
    }

    func availableMonths(for type: ArchiveGameType, policy: ArchiveLoadPolicy) async -> [ArchiveMonth] {
        availableMonthPolicies.append(policy)
        return months
    }

    func loadMonth(
        _ month: ArchiveMonth,
        for type: ArchiveGameType,
        policy: ArchiveLoadPolicy
    ) async -> ArchiveMonthContent {
        let key = ArchiveMonthKey(type: type, month: month)
        loadedMonths.insert(key)
        loadedMonthPolicies[key] = policy
        return content[key] ?? ArchiveMonthContent()
    }

    func loadPolicy(for key: ArchiveMonthKey) -> ArchiveLoadPolicy? {
        loadedMonthPolicies[key]
    }
}

private func makeBackword(id: String, date: String) -> BackwordWord {
    BackwordWord(id: id, date: date, word: "CASTLE", clue: "CHESS")
}

private func makePuzzle(id: String, date: String) -> Puzzle {
    let clue = Clue(
        id: 0,
        direction: .across,
        number: 1,
        text: "Two-letter test answer",
        hint: "First two letters",
        answer: "AB",
        startRow: 0,
        startCol: 0,
        length: 2
    )

    return Puzzle(
        id: id,
        puzzleNumber: 1,
        date: date,
        size: 2,
        cells: [
            [
                CellData(letter: "A", clueNumber: 1, acrossClueId: 0, downClueId: nil),
                CellData(letter: "B", clueNumber: nil, acrossClueId: 0, downClueId: nil),
            ],
            [
                CellData(letter: nil, clueNumber: nil, acrossClueId: nil, downClueId: nil),
                CellData(letter: nil, clueNumber: nil, acrossClueId: nil, downClueId: nil),
            ],
        ],
        clues: [clue]
    )
}
