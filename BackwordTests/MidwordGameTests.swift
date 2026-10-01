import Foundation
import Testing
@testable import Backword

@Suite("Midword rules")
struct MidwordGameTests {
    private func puzzle(date: String = ContentReleaseCalendar().dailyDateString) -> MidwordPuzzle {
        MidwordPuzzle(id: "test", date: date, puzzleNumber: 1,
                      firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: [])
    }

    @Test("Both compounds must use the same middle word")
    func compounds() {
        let game = puzzle()
        #expect(game.isValid)
        #expect(game.firstCompound == "BANKNOTE")
        #expect(game.secondCompound == "NOTEBOOK")
        #expect(game.accepts("NOTE"))
        #expect(!game.accepts("BOOK"))
    }

    @Test("Reviewed same-length alternatives solve the puzzle")
    func approvedAlternative() {
        let original = puzzle()
        let game = MidwordPuzzle(id: original.id, date: original.date,
                                 puzzleNumber: original.puzzleNumber, firstWord: original.firstWord,
                                 secondWord: original.secondWord, answer: original.answer,
                                 alternatives: ["PAGE"])
        #expect(game.isValid)
        var progress = MidwordProgress(date: game.date)
        progress.submit("PAGE", for: game)
        #expect(progress.isWon)
    }

    @Test("All five winning scores", arguments: 1...5)
    func score(guessNumber: Int) {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        for _ in 1..<guessNumber { progress.submit("TEST", for: game) }
        progress.submit("NOTE", for: game)
        #expect(progress.isWon)
        #expect(progress.releaseDateScore == 6 - guessNumber)
        #expect(progress.guesses.count == guessNumber)
    }

    @Test("Five wrong guesses end play without points")
    func failure() {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        for _ in 0..<5 { progress.submit("TEST", for: game) }
        progress.submit("NOTE", for: game)
        #expect(progress.isFailed)
        #expect(progress.guesses.count == 5)
        #expect(progress.releaseDateScore == 0)
    }

    @Test("Archive solutions do not earn release points")
    func lateWin() {
        let game = puzzle(date: "2026-01-01")
        var progress = MidwordProgress(date: game.date)
        progress.submit("NOTE", for: game, at: Date())
        #expect(progress.isWon)
        #expect(progress.releaseDateScore == 0)
    }

    @Test("Duplicate and invalid guesses leave attempts unchanged")
    @MainActor
    func inputRejection() {
        let vm = MidwordViewModel(puzzle: puzzle(), progress: MidwordProgress(date: puzzle().date))
        for character in "ZZZZ" { vm.enterLetter(character) }
        vm.submitGuess(isValidWord: { _ in false })
        #expect(vm.remainingAttempts == 5)
        #expect(vm.input == "ZZZZ")
        #expect(vm.message == "Not in the dictionary")
    }

    @Test("Repeated guesses and extra input do not use another attempt")
    @MainActor
    func duplicateAndInputLimit() {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        progress.submit("TEST", for: game)
        let vm = MidwordViewModel(puzzle: game, progress: progress)
        for character in "TESTX" { vm.enterLetter(character) }
        #expect(vm.input == "TEST")
        vm.submitGuess(isValidWord: { _ in true })
        #expect(vm.remainingAttempts == 4)
        #expect(vm.message == "Already guessed")
    }

    @Test("A completed game stays complete after later submissions")
    func completedGameIsImmutable() {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        progress.submit("NOTE", for: game)
        progress.submit("TEST", for: game)
        #expect(progress.isWon)
        #expect(progress.guesses == ["NOTE"])
    }

    @Test("Cloud resolution prefers a solved record over an incomplete one")
    func cloudResolution() {
        let game = puzzle()
        var local = MidwordProgress(date: game.date)
        local.submit("TEST", for: game)
        var remote = MidwordProgress(date: game.date)
        remote.submit("NOTE", for: game)
        #expect(CloudProgressRanking.shouldReplace(local: local, with: remote))
        #expect(!CloudProgressRanking.shouldReplace(local: remote, with: local))
    }

    @Test("Older saved ratings decode with zero Midword points")
    func ratingMigration() throws {
        let data = Data(#"{"date":"2026-09-30","dailyCrossword":3,"weeklyCrossword":null,"backword":4}"#.utf8)
        let score = try JSONDecoder().decode(DailyScore.self, from: data)
        #expect(score.midword == 0)
        #expect(score.total == 7)
    }

    @Test("Unplayed Midword progress uses the shared New status")
    func newCardStatus() {
        guard case .notStarted = PuzzleStatus.midwordStatus(for: nil),
              case .notStarted = PuzzleStatus.midwordStatus(for: MidwordProgress(date: puzzle().date)) else {
            Issue.record("Missing and empty progress should both show New")
            return
        }
    }

    @Test("An unfinished Midword uses the shared In Progress status")
    func inProgressCardStatus() {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        progress.submit("TEST", for: game)
        guard case .inProgress = PuzzleStatus.midwordStatus(for: progress) else {
            Issue.record("An accepted guess should show In Progress")
            return
        }
    }

    @Test("Midword wins distinguish release-day and late completion", arguments: [false, true])
    func wonCardStatus(late: Bool) {
        let now = Date()
        let game = puzzle(date: late ? "2026-01-01" : ContentReleaseCalendar(now: now).dailyDateString)
        var progress = MidwordProgress(date: game.date)
        progress.submit("NOTE", for: game, at: now)
        let status = PuzzleStatus.midwordStatus(for: progress)
        if late {
            guard case .completedLate = status else {
                Issue.record("Late wins should use the shared Finished status")
                return
            }
        } else {
            guard case .completedOnTime = status else {
                Issue.record("Release-day wins should use the shared Solved status")
                return
            }
        }
    }

    @Test("An exhausted Midword uses the shared Failed status")
    func failedCardStatus() {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        for _ in 0..<5 { progress.submit("TEST", for: game) }
        guard case .failedBackword = PuzzleStatus.midwordStatus(for: progress) else {
            Issue.record("An unsuccessful game should show Failed")
            return
        }
    }
}
