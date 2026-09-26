import Foundation

struct AnagramCompletion: Equatable {
    let puzzle: AnagramPuzzle
    let progress: AnagramProgress

    var isReview: Bool { puzzle.date == "review" }

    var answer: String {
        guard progress.outcome == .solved else { return puzzle.answer }
        return progress.displayedAnswer(for: puzzle) ?? puzzle.answer
    }

    var score: Int {
        guard progress.outcome == .solved else { return 0 }
        if isReview {
            return AnagramProgress.points(
                for: (progress.elapsedSecondsAtCompletion ?? 0) + progress.penaltySeconds
            )
        }
        return progress.releaseDateScore
    }
}

struct AnagramCompletionDisplayState: Equatable {
    enum Style: Equatable {
        case solved
        case finished
        case gaveUp
    }

    let title: String
    let answerIntroduction: String?
    let style: Style

    static func make(completion: AnagramCompletion) -> AnagramCompletionDisplayState {
        if completion.progress.outcome == .gaveUp {
            return AnagramCompletionDisplayState(
                title: "Finished",
                answerIntroduction: "The answer was...",
                style: .gaveUp
            )
        }
        if completion.isReview || completion.progress.releaseDateScore > 0 {
            return AnagramCompletionDisplayState(
                title: "Solved!",
                answerIntroduction: nil,
                style: .solved
            )
        }
        return AnagramCompletionDisplayState(
            title: "Finished",
            answerIntroduction: "Solved after its release day",
            style: .finished
        )
    }
}

enum AnagramCompletionSheetPresentation {
    static func shouldPresent(isComplete: Bool, hasPresented: Bool) -> Bool {
        isComplete && !hasPresented
    }
}

enum AnagramCompletionAnimation {
    static let revealInterval: TimeInterval = 0.12
    static let celebrationDuration: TimeInterval = 0.6

    static func revealSteps(letterCount: Int) -> Range<Int> {
        1..<(max(0, letterCount) + 1)
    }

    static func revealedIndices(letterCount: Int, revealStep: Int) -> Set<Int> {
        guard letterCount > 0, revealStep > 0 else { return [] }
        return Set(0..<min(revealStep, letterCount))
    }

    static func presentationDuration(letterCount: Int, celebrates: Bool) -> TimeInterval {
        Double(max(0, letterCount)) * revealInterval
            + (celebrates ? celebrationDuration : 0.15)
    }
}

enum AnagramCountdownText {
    static func value(
        at date: Date = Date(),
        calendar: Calendar = .current,
        firstRelease: String? = UserDefaults.standard.string(forKey: "Anagram.firstReleaseDate")
    ) -> String {
        let releaseCalendar = ContentReleaseCalendar(now: date, calendar: calendar)
        let seconds: TimeInterval?
        if let firstRelease,
           let firstReleaseDate = releaseDate(firstRelease, calendar: calendar),
           firstReleaseDate > date {
            seconds = firstReleaseDate.timeIntervalSince(date)
        } else {
            seconds = releaseCalendar.secondsUntilDailyRefresh()
        }
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

    private static func releaseDate(_ value: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
