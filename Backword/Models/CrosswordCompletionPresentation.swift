import Foundation

struct CrosswordCompletionCellPosition: Equatable, Hashable {
    let row: Int
    let column: Int

    var revealStep: Int { row + column + 1 }
}

enum CrosswordCompletionAnimation {
    static let revealInterval: TimeInterval = 0.045
    static let finishDuration: TimeInterval = 0.65

    static func revealOrder(cells: [[CellData]]) -> [CrosswordCompletionCellPosition] {
        cells.enumerated()
            .flatMap { row, cells in
                cells.enumerated().compactMap { column, cell in
                    cell.isBlack ? nil : CrosswordCompletionCellPosition(row: row, column: column)
                }
            }
            .sorted {
                if $0.revealStep == $1.revealStep {
                    return $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row
                }
                return $0.revealStep < $1.revealStep
            }
    }

    static func maximumRevealStep(cells: [[CellData]]) -> Int {
        revealOrder(cells: cells).map(\.revealStep).max() ?? 0
    }

    static func presentationDuration(cells: [[CellData]], celebrates: Bool) -> TimeInterval {
        Double(maximumRevealStep(cells: cells)) * revealInterval
            + (celebrates ? finishDuration : 0.15)
    }
}

enum CrosswordCompletionGridStyle: Equatable {
    case solved
    case finished
    case gaveUp

    init(titleStyle: CompletionDisplayState.TitleStyle) {
        switch titleStyle {
        case .solved: self = .solved
        case .finished: self = .finished
        case .gaveUp: self = .gaveUp
        }
    }

    var performsBounce: Bool { self != .gaveUp }
    var showsSparkles: Bool { self == .solved }
}

enum CrosswordReleaseKind: Equatable {
    case daily
    case weekly

    var label: String {
        switch self {
        case .daily: "NEXT DAILY CROSSWORD IN"
        case .weekly: "NEXT WEEKLY CROSSWORD IN"
        }
    }
}

enum CrosswordCountdownText {
    static func value(
        at date: Date = Date(),
        kind: CrosswordReleaseKind,
        calendar: Calendar = .current
    ) -> String {
        let releaseCalendar = ContentReleaseCalendar(now: date, calendar: calendar)
        let seconds: TimeInterval?
        switch kind {
        case .daily:
            seconds = releaseCalendar.secondsUntilDailyRefresh()
        case .weekly:
            seconds = releaseCalendar.secondsUntilWeeklyRefresh()
        }
        return value(secondsRemaining: seconds, kind: kind)
    }

    static func value(secondsRemaining: TimeInterval?, kind: CrosswordReleaseKind) -> String {
        guard let secondsRemaining else { return kind == .daily ? "--:--:--" : "--d --:--:--" }

        let totalSeconds = Int(ceil(max(0, secondsRemaining)))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        switch kind {
        case .daily:
            return String(format: "%02d:%02d:%02d", totalSeconds / 3_600, minutes, seconds)
        case .weekly:
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        }
    }
}

enum CrosswordCompletionMetrics {
    static func score(
        titleStyle: CompletionDisplayState.TitleStyle,
        hasGivenUp: Bool,
        hintsUsed: Int,
        gaveUpScore: Int?,
        savedReleaseDateScore: Int?
    ) -> Int {
        if titleStyle == .finished { return 0 }
        if hasGivenUp { return savedReleaseDateScore ?? gaveUpScore ?? 0 }
        return max(0, 5 - hintsUsed / 3)
    }

    static func streak(stats: UserStats, isWeekly: Bool) -> Int {
        stats.currentStreak(isWeekly: isWeekly)
    }
}
