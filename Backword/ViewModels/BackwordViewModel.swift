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

    // MARK: - Computed

    /// 6 elements. Non-nil positions are revealed letters; nil positions are hidden.
    /// Reveal order: last letter first (index 5), then 4, 3, 2, 1, 0.
    var revealedLetters: [Character?] {
        let letters = Array(word.word)
        return (0..<6).map { i in
            // Reveal from right: position 5 is revealed first, then 4, etc.
            i >= (6 - progress.revealedCount) ? letters[i] : nil
        }
    }

    var isComplete: Bool { progress.isComplete }
    var isWon: Bool { progress.isWon }
    var isFailed: Bool { progress.isFailed }
    var guessCount: Int { progress.guesses.count }
    var maxGuesses: Int { 5 }
    var guessesRemaining: Int { maxGuesses - guessCount }

    /// Number of cells the user types into (the left, not-yet-revealed cells).
    var unrevealedCount: Int { max(0, 6 - progress.revealedCount) }

    /// The revealed letters of the target word that form the suffix of every guess.
    var revealedSuffix: String {
        let letters = Array(word.word.uppercased())
        return (0..<6)
            .filter { $0 >= (6 - progress.revealedCount) }
            .map { String(letters[$0]) }
            .joined()
    }

    var showLetterFeedback: Bool {
        settings.backwordLetterFeedback
    }

    // MARK: - Submit Guess

    func submitGuess() {
        let typed = currentInput.uppercased().filter { $0.isLetter }
        guard typed.count == unrevealedCount, !progress.isComplete else {
            triggerInputError()
            return
        }
        let guess = typed + revealedSuffix
        guard guess.count == 6 else {
            triggerInputError()
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
        } else if progress.guesses.count >= maxGuesses {
            progress.wonFlag = false
            progress.completedAt = Date()
            progress.save()
            stats.record(guessCount: nil, date: word.date)
        } else {
            // Reveal next letter — it will be at the newly revealed index
            let newRevealedCount = progress.revealedCount
            if newRevealedCount > previousRevealedCount {
                let revealedIndex = 6 - newRevealedCount  // index from left that just revealed
                newlyRevealedIndex = revealedIndex
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
