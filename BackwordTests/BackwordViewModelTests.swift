import Testing
@testable import Backword

@Suite("BackwordViewModel Tests")
@MainActor
struct BackwordViewModelTests {

    private func makeWord(_ word: String = "CASTLE") -> BackwordWord {
        BackwordWord(id: "", date: "2026-04-01", word: word, clue: "FORTRESS")
    }

    // MARK: - Initial State

    @Test("Initial state reveals only the last letter")
    func initialRevealedLetters() async throws {
        let vm = BackwordViewModel(word: makeWord())
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
        let vm = BackwordViewModel(word: makeWord())
        #expect(vm.guessCount == 0)
        #expect(vm.isComplete == false)
    }

    // MARK: - Reveal Logic

    @Test("Wrong guess reveals letters matching from the end")
    func wrongGuessRevealsSuffixMatch() async throws {
        // CASTLE = C(0)-A(1)-S(2)-T(3)-L(4)-E(5). Initial unrevealed: [0,1,2,3,4].
        // Type "XAXTL" → buildGuess → XAXTLE; suffix vs CASTLE: E✓,L✓,T✓,X≠S → 3 match
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
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
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in true }
        // Guess 1: "XXXXX" → XXXXE, suffix=1 → revealed {5}
        vm.currentInput = "XXXXX"
        vm.submitGuess()
        // Guess 2: unrevealed=[0,1,2,3,4], "XAXTL" → XAXTLE, suffix=3 (TLE) → revealed {3,4,5}
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

    // MARK: - Win Condition

    @Test("Correct guess triggers win")
    func correctGuessTriggerWin() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
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
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in true }
        // Wrong guess: suffix=1, revealed stays {5}, unrevealed=[0,1,2,3,4]
        vm.currentInput = "XXXXX"
        vm.submitGuess()
        // Win: type CASTL for unrevealed [0,1,2,3,4]
        vm.currentInput = "CASTL"
        vm.submitGuess()

        #expect(vm.isWon == true)
        #expect(vm.isComplete == true)
        #expect(vm.guessCount == 2)
    }

    // MARK: - Fail Condition

    @Test("Five wrong guesses causes failure")
    func fiveWrongGuesessFail() async throws {
        // X guesses always suffix=1, so unrevealedCount stays 5 throughout
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in true }
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
        // unrevealedCount == 5; "CA" (2 chars) is too short
        vm.currentInput = "CA"
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
        vm.currentInput = "ABCDE"  // 5 chars for unrevealed [0,1,2,3,4]
        vm.submitGuess()

        #expect(vm.guessCount == 0)
        #expect(vm.invalidWordMessage != nil)
    }

    @Test("Valid word is accepted")
    func validWordAccepted() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in true }
        vm.currentInput = "ABCDE"  // 5 chars for unrevealed [0,1,2,3,4]
        vm.submitGuess()

        #expect(vm.guessCount == 1)
        #expect(vm.invalidWordMessage == nil)
    }

    @Test("Target word always accepted even if validator rejects it")
    func targetWordAlwaysAccepted() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in false }
        // Unrevealed [0,1,2,3,4] for CASTLE with E(5) revealed: type C,A,S,T,L
        vm.currentInput = "CASTL"
        vm.submitGuess()

        #expect(vm.guessCount == 1)
        #expect(vm.isWon == true)
    }

    @Test("Invalid word does not reveal next letter")
    func invalidWordDoesNotRevealLetter() async throws {
        let vm = BackwordViewModel(word: makeWord("CASTLE"))
        vm.wordValidator = { _ in false }
        let revealedBefore = vm.progress.revealedCount
        vm.currentInput = "XYZQB"  // 5 chars for unrevealed [0,1,2,3,4]
        vm.submitGuess()

        #expect(vm.progress.revealedCount == revealedBefore)
        #expect(vm.guessCount == 0)
    }
}
