import Foundation
import SwiftUI

@MainActor
final class ArchiveViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var selectedTab: ArchiveTab = .backword
    @Published var selectedPuzzle: Puzzle?
    @Published var showPuzzle = false
    @Published var loadingMonths: Set<ArchiveMonthKey> = []
    @Published var unavailableMonths: Set<ArchiveMonthKey> = []

    private let dataSource: ArchiveDataProviding
    private let currentMonth: ArchiveMonth

    @Published private var monthsByType: [ArchiveGameType: [ArchiveMonth]] = [:]
    @Published private var contentByMonth: [ArchiveMonthKey: ArchiveMonthContent] = [:]
    @Published private var expandedMonthByType: [ArchiveGameType: ArchiveMonth] = [:]

    init(
        dataSource: ArchiveDataProviding,
        currentMonth: ArchiveMonth = ArchiveMonth.current()
    ) {
        self.dataSource = dataSource
        self.currentMonth = currentMonth
    }

    var tabs: [ArchiveTab] {
        ArchiveTab.allCases
    }

    var currentTitle: String {
        " \(selectedTab.rawValue) Archive"
    }

    var activeType: ArchiveGameType {
        selectedTab.gameType
    }

    var currentMonthDisplayName: String {
        currentMonth.displayName
    }

    var currentDailyPuzzles: [Puzzle] {
        content(for: currentMonth, type: .daily).dailyPuzzles
    }

    var currentWeeklyPuzzles: [Puzzle] {
        content(for: currentMonth, type: .weekly).weeklyPuzzles
    }

    var currentBackwordWords: [BackwordWord] {
        content(for: currentMonth, type: .backword).backwordWords
    }

    func currentContentIsEmpty(for type: ArchiveGameType) -> Bool {
        content(for: currentMonth, type: type).isEmpty(for: type)
    }

    func earlierMonths(for type: ArchiveGameType) -> [ArchiveMonth] {
        monthsByType[type, default: []].filter { $0 != currentMonth }
    }

    func expandedMonth(for type: ArchiveGameType) -> ArchiveMonth? {
        expandedMonthByType[type]
    }

    func expandedContent(for type: ArchiveGameType) -> ArchiveMonthContent? {
        guard let month = expandedMonth(for: type) else { return nil }
        return contentByMonth[ArchiveMonthKey(type: type, month: month)]
    }

    func isExpanded(_ month: ArchiveMonth, for type: ArchiveGameType) -> Bool {
        expandedMonthByType[type] == month
    }

    func isLoading(_ month: ArchiveMonth, for type: ArchiveGameType) -> Bool {
        loadingMonths.contains(ArchiveMonthKey(type: type, month: month))
    }

    func isUnavailable(_ month: ArchiveMonth, for type: ArchiveGameType) -> Bool {
        unavailableMonths.contains(ArchiveMonthKey(type: type, month: month))
    }

    func expandedScrollToken(for type: ArchiveGameType) -> String? {
        guard let month = expandedMonth(for: type),
              let content = expandedContent(for: type),
              !content.isEmpty(for: type) else {
            return nil
        }

        return "\(type.rawValue)-\(month.key)-\(content.count(for: type))"
    }

    func loadInitialArchive() async {
        defer { isLoading = false }

        async let backwordMonths = dataSource.availableMonths(for: .backword, policy: .cacheFirst)
        async let dailyMonths = dataSource.availableMonths(for: .daily, policy: .cacheFirst)
        async let weeklyMonths = dataSource.availableMonths(for: .weekly, policy: .cacheFirst)

        monthsByType[.backword] = await backwordMonths
        monthsByType[.daily] = await dailyMonths
        monthsByType[.weekly] = await weeklyMonths

        await loadCurrentMonth()
    }

    func expandOrCollapse(_ month: ArchiveMonth, for type: ArchiveGameType) async {
        if expandedMonthByType[type] == month {
            withAnimation(.easeInOut(duration: 0.25)) {
                expandedMonthByType[type] = nil
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            expandedMonthByType[type] = month
        }
        let key = ArchiveMonthKey(type: type, month: month)
        guard contentByMonth[key] == nil else { return }

        loadingMonths = loadingMonths.union([key])
        unavailableMonths = unavailableMonths.subtracting([key])
        let content = await dataSource.loadMonth(month, for: type, policy: .networkFirst)
        withAnimation(.easeInOut(duration: 0.25)) {
            contentByMonth[key] = content
            loadingMonths = loadingMonths.subtracting([key])
        }

        if content.isEmpty(for: type) {
            unavailableMonths = unavailableMonths.union([key])
        }
    }

    func openPuzzle(_ puzzle: Puzzle) {
        selectedPuzzle = puzzle
        showPuzzle = true
    }

    private func loadCurrentMonth() async {
        async let backword = dataSource.loadMonth(currentMonth, for: .backword, policy: .cacheFirst)
        async let daily = dataSource.loadMonth(currentMonth, for: .daily, policy: .cacheFirst)
        async let weekly = dataSource.loadMonth(currentMonth, for: .weekly, policy: .cacheFirst)

        contentByMonth[ArchiveMonthKey(type: .backword, month: currentMonth)] = await backword
        contentByMonth[ArchiveMonthKey(type: .daily, month: currentMonth)] = await daily
        contentByMonth[ArchiveMonthKey(type: .weekly, month: currentMonth)] = await weekly
    }

    private func content(for month: ArchiveMonth, type: ArchiveGameType) -> ArchiveMonthContent {
        contentByMonth[ArchiveMonthKey(type: type, month: month)] ?? ArchiveMonthContent()
    }
}

enum ArchiveTab: String, CaseIterable {
    case backword = "Backword"
    case daily = "Daily\n Crossword"
    case weekly = "Pro\n Crossword"

    var gameType: ArchiveGameType {
        switch self {
        case .backword:
            return .backword
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        }
    }
}

struct ArchiveMonthKey: Hashable {
    let type: ArchiveGameType
    let month: ArchiveMonth
}

private extension ArchiveMonthContent {
    func count(for type: ArchiveGameType) -> Int {
        switch type {
        case .backword:
            return backwordWords.count
        case .daily:
            return dailyPuzzles.count
        case .weekly:
            return weeklyPuzzles.count
        }
    }
}
