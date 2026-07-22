import Foundation
import Testing
@testable import Backword

@Suite("BackwordViewModel Tests")
@MainActor
struct BackwordViewModelTests {

    private func makeWord(_ word: String = "CASTLE") -> BackwordWord {
        BackwordWord(id: UUID().uuidString, date: "test-\(UUID().uuidString)", word: word, clue: "FORTRESS")
    }

    private func makeViewModel(_ word: String = "CASTLE") -> BackwordViewModel {
        let word = makeWord(word)
        return BackwordViewModel(word: word, progress: BackwordProgress(date: word.date))
    }

    // MARK: - Initial State

    @Test("Initial state reveals only the last letter")
    func initialRevealedLetters() async throws {
        let vm = makeViewModel()
        let revealed = vm.revealedLetters

        // Only the last letter (E) is shown at the start
        #expect(revealed[0] == nil)
        #expect(revealed[1] == nil)
        #expect(revealed[2] == nil)
        #expect(revealed[3] == nil)
        #expect(revealed[4] == nil)
        #expect(revealed[5] == Character("E"))
    }

    @Test("Initial guess count is 0")
    func initialGuessCount() async throws {
        let vm = makeViewModel()
        #expect(vm.guessCount == 0)
        #expect(vm.isComplete == false)
    }

    @Test("Guess history identifies the connected correct suffix")
    func guessHistoryIdentifiesConnectedCorrectSuffix() {
        let vm = makeViewModel()

        #expect(vm.correctlyPositionedSuffixIndices(for: "XAXTLE") == Set([3, 4, 5]))
    }

    @Test("Guess history does not highlight disconnected correct letters")
    func guessHistoryDoesNotHighlightDisconnectedCorrectLetters() {
        let vm = makeViewModel()

        #expect(vm.correctlyPositionedSuffixIndices(for: "CXXXXE") == Set([5]))
    }

    @Test("Guess history highlights no cells when the ending is incorrect")
    func guessHistoryHighlightsNoCellsForIncorrectEnding() {
        let vm = makeViewModel()

        #expect(vm.correctlyPositionedSuffixIndices(for: "CASTLY").isEmpty)
    }

    @Test("Backword progress has no score before completion")
    func progressHasNoScoreBeforeCompletion() {
        var progress = BackwordProgress(date: "2026-07-09")
        progress.guesses = ["BRIDGX", "FXASXE"]

        #expect(progress.completedScore == nil)
    }

    @Test("Winning Backword progress scores from guess count")
    func winningProgressScoresFromGuessCount() {
        var progress = BackwordProgress(date: "2026-07-09")
        progress.guesses = ["BRIDGX", "FXASXE", "CASTLE"]
        progress.wonFlag = true
        progress.completedAt = Self.date("2026-07-09 12:00:00")

        #expect(progress.completedScore == 3)
    }

    @Test("Archive Backword win scores zero")
    func archiveBackwordWinScoresZero() {
        var progress = BackwordProgress(date: "2026-07-08")
        progress.guesses = ["BRIDGX", "CASTLE"]
        progress.wonFlag = true
        progress.completedAt = Self.date("2026-07-09 12:00:00")

        #expect(progress.wasCompletedOnReleaseDate == false)
        #expect(progress.completedScore == 0)
    }

    @Test("Archive Backword completion does not update player statistics")
    func archiveBackwordCompletionDoesNotUpdatePlayerStatistics() {
        let word = BackwordWord(
            id: UUID().uuidString,
            date: "2000-01-01",
            word: "CASTLE",
            clue: "FORTRESS"
        )
        let vm = BackwordViewModel(word: word, progress: BackwordProgress(date: word.date))
        let gamesPlayedBeforeCompletion = vm.stats.gamesPlayed
        defer { BackwordProgress.delete(date: word.date) }

        vm.currentInput = "CASTL"
        vm.submitGuess()

        #expect(vm.isWon == true)
        #expect(vm.progress.completedScore == 0)
        #expect(vm.stats.gamesPlayed == gamesPlayedBeforeCompletion)
    }

    @Test("Failed Backword progress scores zero")
    func failedProgressScoresZero() {
        var progress = BackwordProgress(date: "2026-07-09")
        progress.guesses = ["BRIDGX", "FXASXE", "MAXXXX", "PUZZLE", "CASTER"]
        progress.completedAt = Date()

        #expect(progress.completedScore == 0)
    }

    private static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: string)!
    }

    @Test("Saving Backword progress posts changed date notification")
    func savingProgressPostsChangedDateNotification() {
        let date = "test-\(UUID().uuidString)"
        var receivedDate: String?
        let observer = NotificationCenter.default.addObserver(
            forName: .backwordProgressDidChange,
            object: nil,
            queue: nil
        ) { notification in
            receivedDate = notification.userInfo?[BackwordProgress.changedDateUserInfoKey] as? String
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
            BackwordProgress.delete(date: date)
        }

        BackwordProgress(date: date).save()

        #expect(receivedDate == date)
    }

    // MARK: - Reveal Logic

    @Test("Wrong guess with no new suffix match reveals nothing")
    func wrongGuessWithoutSuffixMatchRevealsNothing() {
        let vm = makeViewModel("CASTLE")
        vm.currentInput = "XXXXX"

        vm.submitGuess()

        #expect(vm.revealedLetters == [nil, nil, nil, nil, nil, Character("E")])
        #expect(vm.unrevealedCount == 5)
        #expect(vm.newlyRevealedIndex == nil)
    }

    @Test("One correctly positioned letter connected to the end is revealed")
    func oneConnectedLetterReveals() {
        let vm = makeViewModel("CASTLE")
        vm.currentInput = "XXXXL"

        vm.submitGuess()

        #expect(vm.revealedLetters == [nil, nil, nil, nil, Character("L"), Character("E")])
        #expect(vm.unrevealedCount == 4)
    }

    @Test("Third letter stays hidden through two wrong guesses")
    func thirdLetterStaysHiddenThroughTwoWrongGuesses() {
        let vm = makeViewModel("CASTLE")
        for _ in 0..<2 {
            vm.currentInput = "XXXXX"
            vm.submitGuess()
        }

        #expect(vm.revealedLetters == [nil, nil, nil, nil, nil, Character("E")])
        #expect(vm.unrevealedCount == 5)
    }

    @Test("Third wrong guess reveals the third letter")
    func thirdWrongGuessRevealsThirdLetter() {
        let vm = makeViewModel("CASTLE")
        for _ in 0..<3 {
            vm.currentInput = "XXXXX"
            vm.submitGuess()
        }

        #expect(vm.revealedLetters == [nil, nil, Character("S"), nil, nil, Character("E")])
        #expect(vm.unrevealedCount == 4)
        #expect(vm.newlyRevealedIndex == 2)
    }

    @Test("Third-guess hint can remain disconnected from a revealed suffix")
    func thirdGuessHintCanRemainDisconnectedFromSuffix() {
        let vm = makeViewModel("CASTLE")
        vm.currentInput = "XXXXL"
        vm.submitGuess()
        for _ in 0..<2 {
            vm.currentInput = "XXXX"
            vm.submitGuess()
        }

        #expect(vm.revealedLetters == [nil, nil, Character("S"), nil, Character("L"), Character("E")])
        #expect(vm.unrevealedCount == 3)
    }

    @Test("Wrong guess reveals letters matching from the end")
    func wrongGuessRevealsSuffixMatch() async throws {
        // CASTLE = C(0)-A(1)-S(2)-T(3)-L(4)-E(5). Initial unrevealed: [0,1,2,3,4].
        // Type "XAXTL" → buildGuess → XAXTLE; suffix vs CASTLE: E✓,L✓,T✓,X≠S → 3 match
        let vm = makeViewModel("CASTLE")
        vm.wordValidator = { _ in true }
        vm.currentInput = "XAXTL"
        vm.submitGuess()

        #expect(vm.revealedLetters[3] == Character("T"))
        #expect(vm.revealedLetters[4] == Character("L"))
        #expect(vm.revealedLetters[5] == Character("E"))
        #expect(vm.revealedLetters[0] == nil)
        #expect(vm.revealedLetters[1] == nil)
        #expect(vm.revealedLetters[2] == nil)
        #expect(vm.guessCount == 1)
        #expect(vm.isComplete == false)
    }

    @Test("Maximum suffix match across guesses is used for reveal")
    func multipleWrongGuessesRevealMaxSuffix() async throws {
        // CASTLE = C(0)-A(1)-S(2)-T(3)-L(4)-E(5)
        let vm = makeViewModel("CASTLE")
        vm.wordValidator = { _ in true }
        // Guess 1: "XXXXX" → XXXXXE, suffix=1, so no new letters reveal.
        vm.currentInput = "XXXXX"
        vm.submitGuess()
        // Guess 2: unrevealed=[0,1,2,3,4], "XAXTL" → XAXTLE, suffix=3 (TLE).
        vm.currentInput = "XAXTL"
        vm.submitGuess()
        // Guess 3: unrevealed=[0,1,2], "XBS" → XBSTLE, suffix=4 (STLE) → revealed {2,3,4,5}
        vm.currentInput = "XBS"
        vm.submitGuess()

        #expect(vm.revealedLetters[2] == Character("S"))
        #expect(vm.revealedLetters[3] == Character("T"))
        #expect(vm.revealedLetters[4] == Character("L"))
        #expect(vm.revealedLetters[5] == Character("E"))
        #expect(vm.revealedLetters[0] == nil)
        #expect(vm.revealedLetters[1] == nil)
    }

    @Test("Correct letter disconnected from the end stays hidden")
    func disconnectedCorrectLetterStaysHidden() {
        let vm = makeViewModel("CASTLE")
        vm.currentInput = "CXXXX"

        vm.submitGuess()

        #expect(vm.progress.guesses == ["CXXXXE"])
        #expect(vm.revealedLetters == [nil, nil, nil, nil, nil, Character("E")])
    }

    @Test("Later guesses do not reduce the revealed suffix")
    func laterGuessesPreserveLongestSuffix() {
        let vm = makeViewModel("CASTLE")
        vm.currentInput = "XAXTL"
        vm.submitGuess()

        vm.currentInput = "XXX"
        vm.submitGuess()

        #expect(vm.revealedLetters == [nil, nil, nil, Character("T"), Character("L"), Character("E")])
    }

    @Test("Saved progress is recalculated without automatic reveals")
    func savedProgressUsesCorrectSuffixOnly() {
        let word = makeWord("CASTLE")
        var progress = BackwordProgress(date: word.date)
        progress.guesses = ["XXXXXE", "CXXXXE"]

        let vm = BackwordViewModel(word: word, progress: progress)

        #expect(vm.revealedLetters == [nil, nil, nil, nil, nil, Character("E")])
        #expect(vm.unrevealedCount == 5)
    }

    @Test("Saved progress receives the third-guess hint")
    func savedProgressReceivesThirdGuessHint() {
        let word = makeWord("CASTLE")
        var progress = BackwordProgress(date: word.date)
        progress.guesses = ["XXXXXE", "CXXXXE", "BXXXXE"]

        let vm = BackwordViewModel(word: word, progress: progress)

        #expect(vm.revealedLetters == [nil, nil, Character("S"), nil, nil, Character("E")])
        #expect(vm.unrevealedCount == 4)
    }

    // MARK: - Win Condition

    @Test("Correct guess triggers win")
    func correctGuessTriggerWin() async throws {
        let vm = makeViewModel("CASTLE")
        // Unrevealed [0,1,2,3,4]. Type C,A,S,T,L to form CASTLE.
        vm.currentInput = "CASTL"
        vm.submitGuess()

        #expect(vm.isComplete == true)
        #expect(vm.isWon == true)
        #expect(vm.isFailed == false)
        #expect(vm.guessCount == 1)
    }

    @Test("Correct guess after wrong guesses wins")
    func correctGuessAfterWrongGuesses() async throws {
        let vm = makeViewModel("CASTLE")
        vm.wordValidator = { _ in true }
        // Wrong guess reveals L because it is correctly positioned next to the known E.
        vm.currentInput = "XXXXL"
        vm.submitGuess()
        // Win: type CAST for unrevealed [0,1,2,3]
        vm.currentInput = "CAST"
        vm.submitGuess()

        #expect(vm.isWon == true)
        #expect(vm.isComplete == true)
        #expect(vm.guessCount == 2)
    }

    // MARK: - Fail Condition

    @Test("Five wrong guesses causes failure")
    func fiveWrongGuesessFail() async throws {
        // X guesses always suffix=1, so unrevealedCount stays 5 throughout
        let vm = makeViewModel("CASTLE")
        vm.wordValidator = { _ in true }
        for _ in 0..<5 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }

        #expect(vm.isFailed == true)
        #expect(vm.isWon == false)
        #expect(vm.isComplete == true)
        #expect(vm.didComplete == true)
        #expect(vm.guessCount == 5)
    }

    @Test("No more guesses accepted after game complete")
    func noGuessesAfterComplete() async throws {
        let vm = makeViewModel("CASTLE")
        vm.wordValidator = { _ in true }
        for _ in 0..<5 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }
        // Game is now failed; extra submission must be rejected
        vm.currentInput = "X"
        vm.submitGuess()

        #expect(vm.guessCount == 5)
    }

    #if DEBUG
    @Test("Debug failure simulation creates a transient failed game")
    func debugFailureSimulation() {
        let vm = makeViewModel("CASTLE")

        vm.debugSimulateFailure()

        #expect(vm.isFailed == true)
        #expect(vm.isWon == false)
        #expect(vm.didComplete == true)
        #expect(vm.guessCount == vm.maxGuesses)
        #expect(vm.progress.guesses.contains("CASTLE") == false)
    }
    #endif

    // MARK: - Input Validation

    @Test("Input shorter than required is rejected")
    func shortInputRejected() async throws {
        let vm = makeViewModel()
        // unrevealedCount == 5; "CA" (2 chars) is too short
        vm.currentInput = "CA"
        vm.submitGuess()
        #expect(vm.guessCount == 0)
    }

    @Test("onInputChange filters to uppercase alpha and caps at unrevealedCount")
    func inputChangeFilters() async throws {
        let vm = makeViewModel()
        // Initial unrevealedCount == 5; "castle123!!" filtered+capped = "CASTL"
        vm.onInputChange("castle123!!")
        #expect(vm.currentInput == "CASTL")
    }

    @Test("onInputChange truncates to unrevealedCount characters")
    func inputChangeTruncates() async throws {
        let vm = makeViewModel()
        // Initial unrevealedCount == 5
        vm.onInputChange("ABCDEFGH")
        #expect(vm.currentInput == "ABCDE")
    }

    @Test("Keyboard letter entry uppercases and caps at unrevealed count")
    func keyboardLetterEntryUppercasesAndCaps() async throws {
        let vm = makeViewModel()

        for letter in "castle" {
            vm.enterLetter(letter)
        }

        #expect(vm.currentInput == "CASTL")
    }

    @Test("Keyboard delete removes the last typed letter")
    func keyboardDeleteRemovesLastTypedLetter() async throws {
        let vm = makeViewModel()

        vm.onInputChange("CAST")
        vm.deleteLetter()

        #expect(vm.currentInput == "CAS")
    }

    // MARK: - Clue Hint

    @Test("Clue hint sets flag")
    func clueHintSetsFlag() async throws {
        let vm = makeViewModel()
        #expect(vm.progress.clueRevealed == false)
        vm.revealClueHint()
        #expect(vm.progress.clueRevealed == true)
    }

    @Test("Clue hint is idempotent")
    func clueHintIdempotent() async throws {
        let vm = makeViewModel()
        vm.revealClueHint()
        vm.revealClueHint()
        #expect(vm.progress.clueRevealed == true)
    }

    // MARK: - Letter Feedback

    @Test("lettersInWord returns matching characters")
    func lettersInWordReturnsMatches() async throws {
        let vm = makeViewModel("CASTLE")
        let matching = vm.lettersInWord(for: "CLOCKS")
        #expect(matching.contains("C"))
        #expect(matching.contains("L"))
        #expect(matching.contains("S"))
        #expect(!matching.contains("O"))
        #expect(!matching.contains("K"))
    }

    @Test("lettersInWord returns empty set when no matches")
    func lettersInWordNoMatches() async throws {
        let vm = makeViewModel("CASTLE")
        let matching = vm.lettersInWord(for: "BIRDY")
        #expect(matching.isEmpty)
    }

    // MARK: - Word Validation

    @Test("Any guess is accepted while word validation is disabled")
    func arbitraryGuessAccepted() async throws {
        let vm = makeViewModel("CASTLE")
        vm.wordValidator = { _ in false }
        vm.currentInput = "XYZQB"  // 5 chars for unrevealed [0,1,2,3,4]
        vm.submitGuess()

        #expect(vm.guessCount == 1)
        #expect(vm.progress.guesses == ["XYZQBE"])
        #expect(vm.invalidWordMessage == nil)
    }
}
