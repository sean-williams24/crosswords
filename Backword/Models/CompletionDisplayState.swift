import Foundation

struct CompletionDisplayState: Equatable {
    enum TitleStyle {
        case solved
        case finished
        case gaveUp
    }

    let title: String
    let titleStyle: TitleStyle
    let showsStats: Bool
    let message: String?

    static func make(
        puzzle: Puzzle,
        progress: UserProgress,
        hasGivenUp: Bool,
        calendar: (Date) -> ContentReleaseCalendar = { ContentReleaseCalendar(now: $0) }
    ) -> CompletionDisplayState {
        if hasGivenUp {
            return CompletionDisplayState(
                title: "Gave up",
                titleStyle: .gaveUp,
                showsStats: true,
                message: nil
            )
        }

        let completedAt = progress.completedAt ?? Date()
        let releaseCalendar = calendar(completedAt)
        let completionDate = puzzle.size > 12
            ? releaseCalendar.weeklyDateString
            : releaseCalendar.dailyDateString

        guard completionDate == puzzle.date else {
            let message = puzzle.size > 12
                ? "Complete the puzzle during its release week to earn maximum points."
                : "Complete the puzzle on its release date to earn maximum points."

            return CompletionDisplayState(
                title: "Finished",
                titleStyle: .finished,
                showsStats: false,
                message: message
            )
        }

        return CompletionDisplayState(
            title: "Solved!",
            titleStyle: .solved,
            showsStats: true,
            message: nil
        )
    }
}
