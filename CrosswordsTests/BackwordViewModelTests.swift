import Testing
@testable import Crosswords

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
        vm.currentInput = "BRIDGE"
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
        let wrongGuesses = ["BRIDGE", "FOREST", "PLANET"]

        for guess in wrongGuesses {
            vm.currentInput = guess
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
        vm.currentInput = "CASTLE"
        vm.submitGuess()

        #expect(vm.isComplete == true)
        #expect(vm.isWon == true)
        #expect(vm.isFailed == false)
        #expect(vm.guessCount == 1)
    }

    @Test("Correct guess after wrong guesses wins")
    func correctGuessAfterWrongGuesses() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.currentInput = "BRIDGE"
        vm.submitGuess()
        vm.currentInput = "CASTLE"
        vm.submitGuess()

        #expect(vm.isWon == true)
        #expect(vm.isComplete == true)
        #expect(vm.guessCount == 2)
    }

    // MARK: - Fail Condition

    @Test("Five wrong guesses causes failure")
    func fiveWrongGuesessFail() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        let wrongGuesses = ["BRIDGE", "FOREST", "PLANET", "MARKET", "SILENT"]

        for guess in wrongGuesses {
            vm.currentInput = guess
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
        let wrongGuesses = ["BRIDGE", "FOREST", "PLANET", "MARKET", "SILENT"]
        for guess in wrongGuesses {
            vm.currentInput = guess
            vm.submitGuess()
        }

        // Try one more
        vm.currentInput = "CASTLE"
        vm.submitGuess()

        // Still only 5 guesses
        #expect(vm.guessCount == 5)
    }

    // MARK: - Input Validation

    @Test("Input shorter than 6 is rejected")
    func shortInputRejected() async throws {
        let vm = BackwordViewModel(word: makeWord())
        vm.currentInput = "CAT"
        vm.submitGuess()
        #expect(vm.guessCount == 0)
    }

    @Test("onInputChange filters to 6 uppercase alpha chars")
    func inputChangeFilters() async throws {
        let vm = BackwordViewModel(word: makeWord())
        vm.onInputChange("castle123!!")
        #expect(vm.currentInput == "CASTLE")
    }

    @Test("onInputChange truncates to 6 characters")
    func inputChangeTruncates() async throws {
        let vm = BackwordViewModel(word: makeWord())
        vm.onInputChange("ABCDEFGH")
        #expect(vm.currentInput == "ABCDEF")
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
