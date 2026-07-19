import Foundation

enum BackwordCompletionAnimation {
    static func revealedIndices(letterCount: Int, revealStep: Int) -> Set<Int> {
        guard letterCount > 0, revealStep > 0 else { return [] }
        let visibleCount = min(revealStep, letterCount)
        return Set((letterCount - visibleCount)..<letterCount)
    }
}

enum BackwordCompletionText {
    static func summary(guessCount: Int, isFailed: Bool) -> String {
        guard !isFailed else { return "The answer was..." }

        let noun = guessCount == 1 ? "guess" : "guesses"
        return "... in \(guessCount) \(noun)"
    }
}

enum BackwordCountdownText {
    static func value(at date: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = ContentReleaseCalendar(now: date, calendar: calendar)
            .secondsUntilDailyRefresh()
        return value(secondsRemaining: seconds)
    }

    static func value(secondsRemaining: TimeInterval?) -> String {
        guard let secondsRemaining else { return "--:--:--" }

        let totalSeconds = Int(ceil(max(0, secondsRemaining)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
