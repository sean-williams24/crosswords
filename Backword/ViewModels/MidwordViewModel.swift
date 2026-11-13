import Foundation

@MainActor
final class MidwordViewModel: ObservableObject {
    let puzzle: MidwordPuzzle
    @Published private(set) var progress: MidwordProgress
    @Published private(set) var input = ""
    @Published private(set) var message: String?
    private let haptics: HapticsPlaying

    init(puzzle: MidwordPuzzle, progress: MidwordProgress? = nil, haptics: HapticsPlaying = HapticsEngine()) {
        self.puzzle = puzzle
        self.progress = progress ?? MidwordProgress.load(date: puzzle.date) ?? MidwordProgress(date: puzzle.date)
        self.haptics = haptics
    }

    var hasStarted: Bool { progress.startedAt != nil }

    func start() {
        progress.start()
        progress.save()
    }
    var isComplete: Bool { progress.isComplete }
    var canSubmit: Bool { hasStarted && !isComplete && input.count == puzzle.answer.count }

    func enterLetter(_ letter: Character) {
        let upper = String(letter).uppercased()
        guard hasStarted, !isComplete, input.count < puzzle.answer.count,
              upper.utf8.count == 1,
              let byte = upper.utf8.first, (65...90).contains(byte) else { return }
        input.append(contentsOf: upper)
        message = nil
        haptics.play(.letterEntered)
    }

    func deleteLetter() {
        guard !isComplete, !input.isEmpty else { return }
        input.removeLast()
        message = nil
        haptics.play(.letterEntered)
    }

    func giveUp() {
        guard !isComplete else { return }
        progress.giveUp()
        input = ""
        message = nil
        haptics.play(.backwordGameLost)
        progress.save()
    }

    func submitGuess(isValidWord: (String) -> Bool = WordValidator.isValidEnglishWord) {
        guard canSubmit else { return }
        guard !progress.guesses.contains(input) else {
            message = "Already guessed"
            return
        }
        let isApprovedAnswer = puzzle.accepts(input)
        let hasMultipleDistinctLetters = Set(input).count > 1
        guard isApprovedAnswer || (hasMultipleDistinctLetters && isValidWord(input)) else {
            message = "Not in the dictionary"
            return
        }
        progress.submit(input, for: puzzle)
        if progress.isWon {
            haptics.play(.backwordGameWon)
        } else if progress.isFailed {
            haptics.play(.backwordGameLost)
        } else {
            haptics.play(.backwordGuessIncorrect)
        }
        input = ""
        message = nil
        progress.save()
    }
}
