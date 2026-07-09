import Foundation

struct BackwordCompletionDisplayState: Equatable {
    enum TitleStyle {
        case solved
        case finished
    }

    let title: String?
    let titleStyle: TitleStyle
    let showsStats: Bool
    let message: String?

    static func make(
        progress: BackwordProgress?,
        isCompletion: Bool,
        calendar: (Date) -> ContentReleaseCalendar = { ContentReleaseCalendar(now: $0) }
    ) -> BackwordCompletionDisplayState {
        guard isCompletion else {
            return BackwordCompletionDisplayState(
                title: nil,
                titleStyle: .solved,
                showsStats: true,
                message: nil
            )
        }

        guard let progress, let completedAt = progress.completedAt else {
            return solved
        }

        guard progress.isWon,
              calendar(completedAt).dailyDateString != progress.date else {
            return solved
        }

        return BackwordCompletionDisplayState(
            title: "Finished",
            titleStyle: .finished,
            showsStats: false,
            message: "Complete Backword on its release date to earn maximum points."
        )
    }

    private static var solved: BackwordCompletionDisplayState {
        BackwordCompletionDisplayState(
            title: "Solved!",
            titleStyle: .solved,
            showsStats: true,
            message: nil
        )
    }
}
