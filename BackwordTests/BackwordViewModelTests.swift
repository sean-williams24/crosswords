import Testing
@testable import Backword

@Suite("BackwordViewModel Tests")
@MainActor
struct BackwordViewModelTests {

    private func makeWord(_ word: String = "CASTLE") -> BackwordWord {
        BackwordWord(date: "2026-04-01", word: word, category: "History", definition: "A fortified building.")
    }

    // MARK: - Initial State

    @Test("Initial state reveals only the last letter")
    func initialRevealedLetters() async throws {
        let vm = BackwordViewModel(word: makeWord())
        let revealed = vm.revealedLetters

        // Only index 5 (last) should be non-nil
        #expect(revealed[0] == nil)
        #expect(revealed[1] == nil)
        #expect(revealed[2] == nil)
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
        // Initial: position 5 (E) revealed. User types the 5 unrevealed chars.
        vm.currentInput = "BRIDG"
        vm.submitGuess()

        // After 1 wrong guess: revealedCount == 2 → indices 4 and 5 revealed
        #expect(vm.revealedLetters[4] == Character("L"))
        #expect(vm.revealedLetters[5] == Character("E"))
        #expect(vm.revealedLetters[3] == nil)
        #expect(vm.guessCount == 1)
        #expect(vm.isComplete == false)
    }

    @Test("Each wrong guess reveals one more letter")
    func multipleWrongGuessesRevealLetters() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        // Supply only the unrevealed prefix for each guess; revealed suffix is auto-appended.
        for _ in 0..<3 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }

        // After 3 wrong guesses: revealedCount == 4 → indices 2,3,4,5 revealed (S,T,L,E)
        #expect(vm.revealedLetters[2] == Character("S"))
        #expect(vm.revealedLetters[3] == Character("T"))
        #expect(vm.revealedLetters[4] == Character("L"))
        #expect(vm.revealedLetters[5] == Character("E"))
        #expect(vm.revealedLetters[1] == nil)
        #expect(vm.revealedLetters[0] == nil)
    }

    // MARK: - Win Condition

    @Test("Correct guess triggers win")
    func correctGuessTriggerWin() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        // Initial: position 5 (E) revealed. Type only the 5 unrevealed chars.
        vm.currentInput = "CASTL"
        vm.submitGuess()

        #expect(vm.isComplete == true)
        #expect(vm.isWon == true)
        #expect(vm.isFailed == false)
        #expect(vm.guessCount == 1)
    }

    @Test("Correct guess after wrong guesses wins")
    func correctGuessAfterWrongGuesses() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        // Wrong guess: unrevealed=5, type "BRIDG" → full guess "BRIDGE"
        vm.currentInput = "BRIDG"
        vm.submitGuess()
        // Now unrevealed=4 (L,E revealed). Type "CAST" → full guess "CASTLE"
        vm.currentInput = "CAST"
        vm.submitGuess()

        #expect(vm.isWon == true)
        #expect(vm.isComplete == true)
        #expect(vm.guessCount == 2)
    }

    // MARK: - Fail Condition

    @Test("Five wrong guesses causes failure")
    func fiveWrongGuesessFail() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
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
        for _ in 0..<5 {
            vm.currentInput = String(repeating: "X", count: vm.unrevealedCount)
            vm.submitGuess()
        }

        // Try one more (game is complete, input should be rejected)
        vm.currentInput = "X"
        vm.submitGuess()

        // Still only 5 guesses
        #expect(vm.guessCount == 5)
    }

    // MARK: - Input Validation

    @Test("Input shorter than 6 is rejected")
    func shortInputRejected() async throws {
        let vm = BackwordViewModel(word: makeWord())
        // unrevealedCount == 5; "CAT" (3 chars) is too short
        vm.currentInput = "CAT"
        vm.submitGuess()
        #expect(vm.guessCount == 0)
    }

    @Test("onInputChange filters to uppercase alpha and caps at unrevealedCount")
    func inputChangeFilters() async throws {
        let vm = BackwordViewModel(word: makeWord())
        // Initial unrevealedCount == 5; "castle123!!" filtered+capped = "CASTL"
        vm.onInputChange("castle123!!")
        #expect(vm.currentInput == "CASTL")
    }

    @Test("onInputChange truncates to unrevealedCount characters")
    func inputChangeTruncates() async throws {
        let vm = BackwordViewModel(word: makeWord())
        // Initial unrevealedCount == 5
        vm.onInputChange("ABCDEFGH")
        #expect(vm.currentInput == "ABCDE")
    }

    // MARK: - Category Hint

    @Test("Category hint sets flag")
    func categoryHintSetsFlag() async throws {
        let vm = BackwordViewModel(word: makeWord())
        #expect(vm.progress.categoryHintUsed == false)
        vm.revealCategoryHint()
        #expect(vm.progress.categoryHintUsed == true)
    }

    @Test("Category hint is idempotent")
    func categoryHintIdempotent() async throws {
        let vm = BackwordViewModel(word: makeWord())
        vm.revealCategoryHint()
        vm.revealCategoryHint()
        #expect(vm.progress.categoryHintUsed == true)
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
}
