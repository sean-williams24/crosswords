import SwiftUI

@MainActor
final class BackwordViewModel: ObservableObject {

    let word: BackwordWord
    private(set) var stats: BackwordStats

    @Published var progress: BackwordProgress
    @Published var categoryHintRevealed: Bool
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
        self.categoryHintRevealed = prog.categoryHintUsed
    }

    /// Preview-only initialiser — injects a pre-built progress state.
    init(word: BackwordWord, progress: BackwordProgress) {
        self.word = word
        self.stats = BackwordStats.load()
        self.progress = progress
        self.categoryHintRevealed = progress.categoryHintUsed
    }

    // MARK: - Reveal Sequence

    /// Set of letter indices visible at each `revealedCount` step.
    /// Index 2 (3rd letter) and index 5 (last letter) are pinned from the start.
    /// Wrong guesses reveal indices 4, 3, then index 2's slot is a wasted step
    /// (already shown), then 1 and 0 — keeping all 5 guesses meaningful.
    private static let revealedSets: [Set<Int>] = [
        [2, 5],              // revealedCount 1: game start
        [2, 4, 5],           // revealedCount 2: 1 wrong guess
        [2, 3, 4, 5],        // revealedCount 3: 2 wrong guesses
        [2, 3, 4, 5],        // revealedCount 4: 3 wrong guesses — index 2 already shown (wasted step)
        [1, 2, 3, 4, 5],     // revealedCount 5: 4 wrong guesses
        [0, 1, 2, 3, 4, 5],  // revealedCount 6: failed state — all revealed for display
    ]

    private var revealedIndices: Set<Int> {
        BackwordViewModel.revealedSets[min(progress.revealedCount, 6) - 1]
    }

    /// Exposed for views that display letter cells without a full ViewModel (e.g. BackwordCard).
    static func revealedIndices(forRevealedCount count: Int) -> Set<Int> {
        revealedSets[min(count, 6) - 1]
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

    var showLetterFeedback: Bool {
        settings.backwordLetterFeedback
    }

    var statsIconColour: Color {
        if isFailed {
            return .red
        } else if isWon {
            return .appCorrect
        }
        return .appTextPrimary
    }

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

        // Always accept the target word; otherwise validate against system dictionary
        let isTarget = guess == word.word.uppercased()
        if !isTarget && !wordValidator(guess) {
            triggerInvalidWord()
            return
        }

        let previousRevealedCount = progress.revealedCount
        progress.guesses.append(guess)
        currentInput = ""

        let isCorrect = guess == word.word.uppercased()

        if isCorrect {
            progress.wonFlag = true
            progress.completedAt = Date()
            progress.save()
            stats.record(guessCount: progress.guesses.count, date: word.date)
            OverallRatingService().recordBackword(guessCount: progress.guesses.count, date: word.date)
        } else if progress.guesses.count >= maxGuesses {
            progress.wonFlag = false
            progress.completedAt = Date()
            progress.save()
            stats.record(guessCount: nil, date: word.date)
            OverallRatingService().recordBackword(guessCount: nil, date: word.date)
        } else {
            // Reveal next letter — determine which index was newly revealed
            let newRevealedCount = progress.revealedCount
            if newRevealedCount > previousRevealedCount {
                let prevSet = BackwordViewModel.revealedSets[previousRevealedCount - 1]
                let newSet = BackwordViewModel.revealedSets[min(newRevealedCount, 6) - 1]
                newlyRevealedIndex = newSet.subtracting(prevSet).min()
                progress.save()
                // Clear the highlight after the animation
                Task {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    newlyRevealedIndex = nil
                }
            } else {
                progress.save()
            }
        }
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

    func revealCategoryHint() {
        guard !progress.categoryHintUsed else { return }
        progress.categoryHintUsed = true
        categoryHintRevealed = true
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
        "Invalid word",
        "Made up words are n/a"
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
