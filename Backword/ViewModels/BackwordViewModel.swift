import SwiftUI

@MainActor
final class BackwordViewModel: ObservableObject {

    let word: BackwordWord
    private(set) var stats: BackwordStats

    @Published var progress: BackwordProgress
    @Published var clueRevealed: Bool
    @Published var currentInput: String = ""
    @Published var newlyRevealedIndex: Int? = nil
    @Published var inputError: Bool = false
    @Published var invalidWordMessage: String? = nil

    private let settings = AppSettings.shared

    init(word: BackwordWord) {
        self.word = word
        self.stats = BackwordStats.load()
        let prog = BackwordProgress.load(date: word.date) ?? BackwordProgress(date: word.date)
        self.progress = prog
        self.clueRevealed = prog.clueRevealed
    }

    /// Preview-only initialiser — injects a pre-built progress state.
    init(word: BackwordWord, progress: BackwordProgress) {
        self.word = word
        self.stats = BackwordStats.load()
        self.progress = progress
        self.clueRevealed = progress.clueRevealed
    }

    // MARK: - Reveal Sequence

    private var revealedIndices: Set<Int> {
        BackwordViewModel.suffixRevealedIndices(progress: progress, word: word.word)
    }

    /// Exposed for views that display letter cells without a full ViewModel (e.g. BackwordCard).
    static func revealedIndices(for progress: BackwordProgress?, word: String) -> Set<Int> {
        suffixRevealedIndices(progress: progress, word: word)
    }

    private static func suffixRevealedIndices(progress: BackwordProgress?, word: String) -> Set<Int> {
        guard let progress else { return [5] }
        if progress.isFailed { return Set(0..<6) }
        let target = Array(word.uppercased())
        let wrongGuesses = progress.isWon ? Array(progress.guesses.dropLast()) : progress.guesses
        var maxSuffix = wrongGuesses.count + 1
        for guess in wrongGuesses {
            let g = Array(guess.uppercased())
            guard g.count == 6, target.count == 6 else { continue }
            var match = 0
            for i in stride(from: 5, through: 0, by: -1) {
                if g[i] == target[i] { match += 1 } else { break }
            }
            maxSuffix = max(maxSuffix, match)
        }
        return Set((6 - maxSuffix)..<6)
    }

    // MARK: - Computed

    /// 6 elements. Non-nil where the letter is visible, nil where the user must type.
    var revealedLetters: [Character?] {
        let letters = Array(word.word)
        let revealed = revealedIndices
        return (0..<6).map { i in revealed.contains(i) ? letters[i] : nil }
    }

    /// Sorted indices of cells the user still needs to type into.
    var unrevealedIndices: [Int] {
        (0..<6).filter { !revealedIndices.contains($0) }
    }

    var isComplete: Bool { progress.isComplete }
    var isWon: Bool { progress.isWon }
    var isFailed: Bool { progress.isFailed }
    var guessCount: Int { progress.guesses.count }
    var maxGuesses: Int { 5 }
    var guessesRemaining: Int { maxGuesses - guessCount }

    /// Number of cells the user types into.
    var unrevealedCount: Int { unrevealedIndices.count }
    var didComplete = false

    var showLetterFeedback: Bool {
        settings.backwordLetterFeedback
    }

    var showOnboarding: Bool {
        !settings.hasSeenBackwordOnboarding
    }

    func hasSeenOnboarding() {
        settings.hasSeenBackwordOnboarding = true
    }

    var statsIconColour: Color {
        if isFailed {
            return .red
        } else if isWon {
            return .appCorrect
        }
        return .appTextPrimary
    }

    #if DEBUG
    /// Moves the current game into a transient failed state so the failure
    /// completion experience can be exercised without changing saved progress or stats.
    func debugSimulateFailure() {
        guard !progress.isComplete else { return }

        let target = word.word.uppercased()
        let mockGuesses = ["PLANET", "STREAM", "BRIDGE", "MARKET", "SILVER", "GARDEN"]
            .filter { $0 != target }

        progress.guesses = Array(mockGuesses.prefix(maxGuesses))
        progress.wonFlag = false
        didComplete = true
        progress.completedAt = Date()
    }
    #endif

    // MARK: - Submit Guess

    func submitGuess() {
        let typed = currentInput.uppercased().filter { $0.isLetter }
        guard typed.count == unrevealedCount, !progress.isComplete else {
            triggerInputError()
            return
        }
        let guess = buildGuess(from: typed)
        guard guess.count == 6 else {
            triggerInputError()
            return
        }

        // Temporarily allow any six-letter guess. Keep the validation logic here so
        // it can be restored when legitimate-word enforcement is re-enabled.
//        let isTarget = guess == word.word.uppercased()
//        if !isTarget && !wordValidator(guess) {
//            triggerInvalidWord()
//            return
//        }

        let prevRevealed = revealedIndices
        progress.guesses.append(guess)
        currentInput = ""

        let isCorrect = guess == word.word.uppercased()

        if isCorrect {
            progress.wonFlag = true
            didComplete = true
            progress.completedAt = Date()
            progress.save()
            recordCompletion(guessCount: progress.guesses.count)
        } else if progress.guesses.count >= maxGuesses {
            progress.wonFlag = false
            didComplete = true
            progress.completedAt = Date()
            progress.save()
            recordCompletion(guessCount: nil)
        } else {
            let justRevealed = revealedIndices.subtracting(prevRevealed)
            progress.save()
            if !justRevealed.isEmpty {
                newlyRevealedIndex = justRevealed.min()
                Task {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    newlyRevealedIndex = nil
                }
            }
        }
    }

    private func recordCompletion(guessCount: Int?) {
        guard progress.wasCompletedOnReleaseDate, let completedAt = progress.completedAt else { return }

        stats.record(guessCount: guessCount, date: word.date)
        OverallRatingService().recordBackword(
            guessCount: guessCount,
            date: word.date,
            releaseCalendar: ContentReleaseCalendar(now: completedAt)
        )
    }

    /// Assembles the full 6-letter guess by placing typed characters into unrevealed positions
    /// and known letters into revealed positions.
    private func buildGuess(from typed: String) -> String {
        let letters = Array(word.word.uppercased())
        let revealed = revealedIndices
        let typedChars = Array(typed)
        var typedIdx = 0
        return (0..<6).map { i -> String in
            if revealed.contains(i) {
                return String(letters[i])
            } else {
                defer { typedIdx += 1 }
                return typedIdx < typedChars.count ? String(typedChars[typedIdx]) : ""
            }
        }.joined()
    }

    func revealClueHint() {
        guard !progress.clueRevealed else { return }
        progress.clueRevealed = true
        clueRevealed = true
        progress.save()
    }

    /// Returns the set of characters from `guess` that appear anywhere in the target word.
    func lettersInWord(for guess: String) -> Set<Character> {
        let targetLetters = Set(word.word.uppercased())
        return Set(guess.uppercased()).intersection(targetLetters)
    }

    // MARK: - Input Handling

    func onInputChange(_ newValue: String) {
        let filtered = newValue.uppercased().filter { $0.isLetter }
        currentInput = String(filtered.prefix(unrevealedCount))
    }

    func enterLetter(_ letter: Character) {
        guard !progress.isComplete else { return }
        onInputChange(currentInput + String(letter))
    }

    func deleteLetter() {
        guard !progress.isComplete, !currentInput.isEmpty else { return }
        currentInput.removeLast()
    }

    private func triggerInputError() {
        inputError = true
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            inputError = false
        }
    }

    private var invalidWords: Set<String> = [
        "Not a valid word",
        "Real words only",
        "Invalid word"
    ]

    private func triggerInvalidWord() {
        invalidWordMessage = invalidWords.randomElement()
        triggerInputError()
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            invalidWordMessage = nil
        }
    }

    // Indirection for testability — tests can inject a custom validator.
    var wordValidator: (String) -> Bool = { WordValidator.isValidEnglishWord($0) }

    // MARK: - Share

    var shareText: String {
        let header = "Backword \(word.date)"
        let result = isWon ? "Got it in \(guessCount)/\(maxGuesses)!" : "Failed (\(word.word))"
        let guessBlocks = progress.guesses.map { guess -> String in
            guard isWon, let last = progress.guesses.last, guess == last else {
                return String(repeating: "⬛", count: 6)
            }
            return String(repeating: "🟩", count: 6)
        }.joined(separator: "\n")
        return "\(header)\n\(result)\n\(guessBlocks)"
    }
}
