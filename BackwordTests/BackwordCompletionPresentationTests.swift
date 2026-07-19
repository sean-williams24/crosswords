import Foundation
import Testing
@testable import Backword

@Suite("Backword Completion Presentation Tests")
struct BackwordCompletionPresentationTests {
    @Test("Completion letters reveal from right to left")
    func completionLettersRevealFromRightToLeft() {
        #expect(BackwordCompletionAnimation.revealedIndices(letterCount: 6, revealStep: 0) == [])
        #expect(BackwordCompletionAnimation.revealedIndices(letterCount: 6, revealStep: 1) == [5])
        #expect(BackwordCompletionAnimation.revealedIndices(letterCount: 6, revealStep: 3) == [3, 4, 5])
        #expect(BackwordCompletionAnimation.revealedIndices(letterCount: 6, revealStep: 6) == [0, 1, 2, 3, 4, 5])
    }

    @Test("Completion reveal clamps steps to the word length")
    func completionRevealClampsStepsToWordLength() {
        #expect(BackwordCompletionAnimation.revealedIndices(letterCount: 6, revealStep: 20) == [0, 1, 2, 3, 4, 5])
        #expect(BackwordCompletionAnimation.revealedIndices(letterCount: 0, revealStep: 1) == [])
    }

    @Test("Completion guess summary handles singular and plural wording")
    func completionGuessSummaryHandlesSingularAndPluralWording() {
        #expect(BackwordCompletionText.summary(guessCount: 1, isFailed: false) == "... in 1 guess")
        #expect(BackwordCompletionText.summary(guessCount: 3, isFailed: false) == "... in 3 guesses")
    }

    @Test("Failed completion introduces the answer")
    func failedCompletionIntroducesTheAnswer() {
        #expect(BackwordCompletionText.summary(guessCount: 5, isFailed: true) == "The answer was...")
    }

    @Test("Countdown formats hours minutes and seconds")
    func countdownFormatsHoursMinutesAndSeconds() {
        #expect(BackwordCountdownText.value(secondsRemaining: 3_661) == "01:01:01")
        #expect(BackwordCountdownText.value(secondsRemaining: 45) == "00:00:45")
        #expect(BackwordCountdownText.value(secondsRemaining: nil) == "--:--:--")
    }

    @Test("Countdown uses the next local midnight")
    func countdownUsesNextLocalMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-03T22:15:00Z"))

        #expect(BackwordCountdownText.value(at: now, calendar: calendar) == "00:45:00")
    }
}
