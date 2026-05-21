import Testing
@testable import Backword

@Suite("BackwordViewModel Tests")
@MainActor
struct BackwordViewModelTests {

    private func makeWord(_ word: String = "CASTLE") -> BackwordWord {
        BackwordWord(id: "", date: "2026-04-01", word: word, clue: "FORTRESS")
    }

    // MARK: - Initial State

    @Test("Initial state reveals the 3rd and last letters")
    func initialRevealedLetters() async throws {
        let vm = BackwordViewModel(word: makeWord())
        let revealed = vm.revealedLetters

        // Index 2 (S) and index 5 (E) are pinned from the start
        #expect(revealed[0] == nil)
        #expect(revealed[1] == nil)
        #expect(revealed[2] == Character("S"))
        #expect(revealed[3] == nil)
        #expect(revealed[4] == nil)
        #expect(revealed[5] == Character("E"))
    }

    @Test("Initial guess count is 0")
    func initialGuessCount() async throws {
        let vm = BackwordViewModel(word: makeWord())
        #expect(vm.guessCount == 0)
        #expect(vm.isComplete == false)
    }

    // MARK: - Reveal Logic

    @Test("Wrong guess reveals next letter from right")
    func wrongGuessRevealsNextLetter() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in true }
        // Pinned: index 2 (S) and 5 (E). Unrevealed: [0,1,3,4] — type 4 chars.
        vm.currentInput = "ABCD"
        vm.submitGuess()

        // After 1 wrong guess: additionally reveals index 4 (L)
        #expect(vm.revealedLetters[2] == Character("S"))
        #expect(vm.revealedLetters[4] == Character("L"))
        #expect(vm.revealedLetters[5] == Character("E"))
        #expect(vm.revealedLetters[0] == nil)
        #expect(vm.revealedLetters[1] == nil)
        #expect(vm.revealedLetters[3] == nil)
        #expect(vm.guessCount == 1)
        #expect(vm.isComplete == false)
    }

    @Test("Each wrong guess reveals one more letter")
    func multipleWrongGuessesRevealLetters() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in true }
        for _ in 0..<3 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }

        // After 3 wrong guesses: revealedCount=4 — wasted step (index 2 already shown)
        // Revealed: {2,3,4,5}; indices 0 (C) and 1 (A) still hidden
        #expect(vm.revealedLetters[2] == Character("S"))
        #expect(vm.revealedLetters[3] == Character("T"))
        #expect(vm.revealedLetters[4] == Character("L"))
        #expect(vm.revealedLetters[5] == Character("E"))
        #expect(vm.revealedLetters[0] == nil)
        #expect(vm.revealedLetters[1] == nil)
    }

    // MARK: - Win Condition

    @Test("Correct guess triggers win")
    func correctGuessTriggerWin() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        // Pinned: S(2), E(5). Unrevealed: [0,1,3,4]. Type C,A,T,L to form CASTLE.
        vm.currentInput = "CATL"
        vm.submitGuess()

        #expect(vm.isComplete == true)
        #expect(vm.isWon == true)
        #expect(vm.isFailed == false)
        #expect(vm.guessCount == 1)
    }

    @Test("Correct guess after wrong guesses wins")
    func correctGuessAfterWrongGuesses() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in true }
        // Wrong guess: unrevealed=[0,1,3,4], type 4 chars
        vm.currentInput = "ABCD"
        vm.submitGuess()
        // Now unrevealed=[0,1,3] (L,E,S revealed). Type C,A,T to form CASTLE.
        vm.currentInput = "CAT"
        vm.submitGuess()

        #expect(vm.isWon == true)
        #expect(vm.isComplete == true)
        #expect(vm.guessCount == 2)
    }

    // MARK: - Fail Condition

    @Test("Five wrong guesses causes failure")
    func fiveWrongGuesessFail() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in true }
        // Guess 3 and 4 both have unrevealedCount=2 (wasted step at revealedCount=4);
        // guess 5 has unrevealedCount=1 — wrong → isFailed.
        for _ in 0..<5 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }

        #expect(vm.isFailed == true)
        #expect(vm.isWon == false)
        #expect(vm.isComplete == true)
        #expect(vm.guessCount == 5)
    }

    @Test("No more guesses accepted after game complete")
    func noGuessesAfterComplete() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
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

    // MARK: - Input Validation

    @Test("Input shorter than required is rejected")
    func shortInputRejected() async throws {
        let vm = BackwordViewModel(word: makeWord())
        // unrevealedCount == 4; "CA" (2 chars) is too short
        vm.currentInput = "CA"
        vm.submitGuess()
        #expect(vm.guessCount == 0)
    }

    @Test("onInputChange filters to uppercase alpha and caps at unrevealedCount")
    func inputChangeFilters() async throws {
        let vm = BackwordViewModel(word: makeWord())
        // Initial unrevealedCount == 4; "castle123!!" filtered+capped = "CAST"
        vm.onInputChange("castle123!!")
        #expect(vm.currentInput == "CAST")
    }

    @Test("onInputChange truncates to unrevealedCount characters")
    func inputChangeTruncates() async throws {
        let vm = BackwordViewModel(word: makeWord())
        // Initial unrevealedCount == 4
        vm.onInputChange("ABCDEFGH")
        #expect(vm.currentInput == "ABCD")
    }

    // MARK: - Clue Hint

    @Test("Clue hint sets flag")
    func clueHintSetsFlag() async throws {
        let vm = BackwordViewModel(word: makeWord())
        #expect(vm.progress.clueRevealed == false)
        vm.revealClueHint()
        #expect(vm.progress.clueRevealed == true)
    }

    @Test("Clue hint is idempotent")
    func clueHintIdempotent() async throws {
        let vm = BackwordViewModel(word: makeWord())
        vm.revealClueHint()
        vm.revealClueHint()
        #expect(vm.progress.clueRevealed == true)
    }

    // MARK: - Letter Feedback

    @Test("lettersInWord returns matching characters")
    func lettersInWordReturnsMatches() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        let matching = vm.lettersInWord(for: "CLOCKS")
        #expect(matching.contains("C"))
        #expect(matching.contains("L"))
        #expect(matching.contains("S"))
        #expect(!matching.contains("O"))
        #expect(!matching.contains("K"))
    }

    @Test("lettersInWord returns empty set when no matches")
    func lettersInWordNoMatches() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        let matching = vm.lettersInWord(for: "BIOPSY")
        #expect(matching.isEmpty)
    }

    // MARK: - Word Validation

    @Test("Invalid word is rejected and guess not consumed")
    func invalidWordRejected() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in false }
        vm.currentInput = "ABCD"  // 4 chars for unrevealed [0,1,3,4]
        vm.submitGuess()

        #expect(vm.guessCount == 0)
        #expect(vm.invalidWordMessage != nil)
    }

    @Test("Valid word is accepted")
    func validWordAccepted() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in true }
        vm.currentInput = "ABCD"  // 4 chars for unrevealed [0,1,3,4]
        vm.submitGuess()

        #expect(vm.guessCount == 1)
        #expect(vm.invalidWordMessage == nil)
    }

    @Test("Target word always accepted even if validator rejects it")
    func targetWordAlwaysAccepted() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in false }
        // Unrevealed [0,1,3,4] for CASTLE with S(2),E(5) pinned: type C,A,T,L
        vm.currentInput = "CATL"
        vm.submitGuess()

        #expect(vm.guessCount == 1)
        #expect(vm.isWon == true)
    }

    @Test("Invalid word does not reveal next letter")
    func invalidWordDoesNotRevealLetter() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in false }
        let revealedBefore = vm.progress.revealedCount
        vm.currentInput = "XYZQ"  // 4 chars for unrevealed [0,1,3,4]
        vm.submitGuess()

        #expect(vm.progress.revealedCount == revealedBefore)
        #expect(vm.guessCount == 0)
    }
}
