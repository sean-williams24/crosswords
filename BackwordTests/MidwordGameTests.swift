import Foundation
import Testing
@testable import Backword

@Suite("Midword rules")
struct MidwordGameTests {
    private func puzzle(date: String = ContentReleaseCalendar().dailyDateString) -> MidwordPuzzle {
        MidwordPuzzle(id: "test", date: date, puzzleNumber: 1,
                      firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: [])
    }

    @Test("Giving up preserves guesses, finishes for zero points, and prevents further guesses")
    func giveUp() {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        progress.start()
        progress.submit("PAGE", for: game)
        let now = Date()
        progress.giveUp(at: now)
        progress.submit(game.answer, for: game)
        progress.giveUp(at: now.addingTimeInterval(10))
        #expect(progress.guesses == ["PAGE"])
        #expect(progress.isFailed)
        #expect(progress.completedAt == now)
        #expect(progress.releaseDateScore == 0)
    }

    @Test("Every Midword sheet blurs the presenting view", arguments: [
        MidwordSheetPresentation(showsStats: true),
        MidwordSheetPresentation(showsInstructions: true),
        MidwordSheetPresentation(showsCompletion: true)
    ])
    func sheetPresentationBlur(presentation: MidwordSheetPresentation) {
        #expect(presentation.isPresentingSheet)
    }

    @Test("Midword view is not blurred without a sheet")
    func noSheetPresentationBlur() {
        #expect(!MidwordSheetPresentation().isPresentingSheet)
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
        progress.start()
        progress.submit("PAGE", for: game)
        #expect(progress.isWon)
    }

    @Test("Guess count does not reduce a quick solve score", arguments: 1...5)
    func score(guessNumber: Int) {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        progress.start()
        for _ in 1..<guessNumber { progress.submit("TEST", for: game) }
        progress.submit("NOTE", for: game)
        #expect(progress.isWon)
        #expect(progress.releaseDateScore == 5)
        #expect(progress.guesses.count == guessNumber)
    }

    @Test("Five wrong guesses do not end play")
    func failure() {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        progress.start()
        for _ in 0..<5 { progress.submit("TEST", for: game) }
        progress.submit("NOTE", for: game)
        #expect(progress.isWon)
        #expect(progress.guesses.count == 6)
        #expect(progress.releaseDateScore == 5)
    }

    @Test("Archive solutions do not earn release points")
    func lateWin() {
        let game = puzzle(date: "2026-01-01")
        var progress = MidwordProgress(date: game.date)
        progress.start()
        progress.submit("NOTE", for: game, at: Date())
        #expect(progress.isWon)
        #expect(progress.releaseDateScore == 0)
    }

    @Test("Duplicate and invalid guesses leave attempts unchanged")
    @MainActor
    func inputRejection() {
        let vm = MidwordViewModel(puzzle: puzzle(), progress: MidwordProgress(date: puzzle().date))
        vm.start()
        for character in "ZZZZ" { vm.enterLetter(character) }
        vm.submitGuess(isValidWord: { _ in false })
        #expect(vm.progress.guesses.isEmpty)
        #expect(vm.input == "ZZZZ")
        #expect(vm.message == "Not in the dictionary")

        vm.deleteLetter()
        #expect(vm.message == nil)
    }

    @Test("Repeated-letter strings are rejected even when the dictionary accepts them")
    @MainActor
    func repeatedLetterRejection() {
        let game = puzzle()
        let vm = MidwordViewModel(puzzle: game, progress: MidwordProgress(date: game.date))
        vm.start()
        for character in "DDDD" { vm.enterLetter(character) }

        vm.submitGuess(isValidWord: { _ in true })

        #expect(vm.progress.guesses.isEmpty)
        #expect(vm.input == "DDDD")
        #expect(vm.message == "Not in the dictionary")
    }

    @Test("Repeated guesses and extra input do not use another attempt")
    @MainActor
    func duplicateAndInputLimit() {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        progress.start()
        progress.submit("TEST", for: game)
        let vm = MidwordViewModel(puzzle: game, progress: progress)
        for character in "TESTX" { vm.enterLetter(character) }
        #expect(vm.input == "TEST")
        vm.submitGuess(isValidWord: { _ in true })
        #expect(vm.progress.guesses.count == 1)
        #expect(vm.message == "Already guessed")
    }

    @Test("Submit is available only while the answer input is full")
    @MainActor
    func submitAvailability() {
        let game = puzzle()
        let vm = MidwordViewModel(puzzle: game, progress: MidwordProgress(date: game.date))
        #expect(!vm.canSubmit)
        vm.start()
        for character in "NOT" { vm.enterLetter(character) }
        #expect(!vm.canSubmit)
        vm.enterLetter("E")
        #expect(vm.canSubmit)
        vm.deleteLetter()
        #expect(!vm.canSubmit)
        vm.enterLetter("E")
        #expect(vm.canSubmit)
    }

    @Test("Completed games never offer Submit", arguments: [false, true])
    @MainActor
    func completedSubmitAvailability(won: Bool) {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        progress.start()
        if won {
            progress.submit("NOTE", for: game)
        } else {
            progress.giveUp()
        }
        let vm = MidwordViewModel(puzzle: game, progress: progress)
        for character in "NOTE" { vm.enterLetter(character) }
        #expect(vm.isComplete)
        #expect(vm.input.isEmpty)
        #expect(!vm.canSubmit)
    }

    @Test("A completed game stays complete after later submissions")
    func completedGameIsImmutable() {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        progress.start()
        progress.submit("NOTE", for: game)
        progress.submit("TEST", for: game)
        #expect(progress.isWon)
        #expect(progress.guesses == ["NOTE"])
    }

    @Test("Cloud resolution prefers a solved record over an incomplete one")
    func cloudResolution() {
        let game = puzzle()
        var local = MidwordProgress(date: game.date)
        local.start()
        local.submit("TEST", for: game)
        var remote = MidwordProgress(date: game.date)
        remote.start()
        remote.submit("NOTE", for: game)
        #expect(MidwordProgress.merged(local, remote).isWon)
        #expect(MidwordProgress.merged(remote, local).isWon)
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
        progress.start()
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
        progress.start()
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

    @Test("Giving up uses the shared give-up status")
    func failedCardStatus() {
        let game = puzzle()
        var progress = MidwordProgress(date: game.date)
        progress.start()
        for _ in 0..<5 { progress.submit("TEST", for: game) }
        progress.giveUp()
        guard case .gaveUp = PuzzleStatus.midwordStatus(for: progress) else {
            Issue.record("An unsuccessful game should show Failed")
            return
        }
    }
}
