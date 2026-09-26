import Foundation
import Testing
@testable import Backword

@Suite("Anagram completion presentation")
struct AnagramCompletionPresentationTests {
    private let puzzle = AnagramPuzzle(
        id: "anagram", date: "2026-10-01", puzzleNumber: 1, schemaVersion: 1,
        answer: "TRIANGLE", acceptedAnswers: ["INTEGRAL"], initialScramble: "RAGTLINE"
    )

    @Test("Letters reveal from left to right")
    func lettersRevealFromLeftToRight() {
        #expect(AnagramCompletionAnimation.revealedIndices(letterCount: 8, revealStep: 0) == [])
        #expect(AnagramCompletionAnimation.revealedIndices(letterCount: 8, revealStep: 3) == [0, 1, 2])
        #expect(AnagramCompletionAnimation.revealedIndices(letterCount: 8, revealStep: 20) == Set(0..<8))
        #expect(Array(AnagramCompletionAnimation.revealSteps(letterCount: 3)) == [1, 2, 3])
    }

    @Test("Completion state distinguishes solved, late, and revealed answers")
    func completionStates() {
        var solved = AnagramProgress(puzzle: puzzle)
        solved.outcome = .solved
        solved.completedAt = Date()
        solved.elapsedSecondsAtCompletion = 45
        solved.releaseDateScore = 4

        var late = solved
        late.releaseDateScore = 0

        var gaveUp = solved
        gaveUp.outcome = .gaveUp

        #expect(AnagramCompletionDisplayState.make(completion: .init(puzzle: puzzle, progress: solved)).style == .solved)
        #expect(AnagramCompletionDisplayState.make(completion: .init(puzzle: puzzle, progress: late)).style == .finished)
        #expect(AnagramCompletionDisplayState.make(completion: .init(puzzle: puzzle, progress: gaveUp)).style == .gaveUp)
    }

    @Test("Review score is displayed without a release rating score")
    func reviewScore() {
        let review = AnagramPuzzle(
            id: "review", date: "review", puzzleNumber: 0, schemaVersion: 1,
            answer: "TRIANGLE", acceptedAnswers: [], initialScramble: "RAGTLINE"
        )
        var progress = AnagramProgress(puzzle: review)
        progress.outcome = .solved
        progress.completedAt = Date()
        progress.elapsedSecondsAtCompletion = 75

        let completion = AnagramCompletion(puzzle: review, progress: progress)
        #expect(completion.score == 3)
        #expect(AnagramCompletionDisplayState.make(completion: completion).style == .solved)
    }

    @Test("A completed game presents its completion sheet once")
    func completionSheetPresentation() {
        #expect(AnagramCompletionSheetPresentation.shouldPresent(isComplete: true, hasPresented: false))
        #expect(!AnagramCompletionSheetPresentation.shouldPresent(isComplete: true, hasPresented: true))
        #expect(!AnagramCompletionSheetPresentation.shouldPresent(isComplete: false, hasPresented: false))
    }

    @Test("Countdown formats time and respects the first release")
    func countdown() throws {
        #expect(AnagramCountdownText.value(secondsRemaining: 3_661) == "01:01:01")
        #expect(AnagramCountdownText.value(secondsRemaining: nil) == "--:--:--")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let beforeLaunch = try #require(ISO8601DateFormatter().date(from: "2026-09-30T22:00:00Z"))
        #expect(AnagramCountdownText.value(
            at: beforeLaunch,
            calendar: calendar,
            firstRelease: "2026-10-01"
        ) == "01:00:00")

        let afterLaunch = try #require(ISO8601DateFormatter().date(from: "2026-10-02T22:15:00Z"))
        #expect(AnagramCountdownText.value(
            at: afterLaunch,
            calendar: calendar,
            firstRelease: "2026-10-01"
        ) == "00:45:00")
    }
}
