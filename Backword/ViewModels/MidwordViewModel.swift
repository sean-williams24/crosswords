import Foundation

@MainActor
final class MidwordViewModel: ObservableObject {
    let puzzle: MidwordPuzzle
    @Published private(set) var progress: MidwordProgress
    @Published private(set) var input = ""
    @Published private(set) var message: String?
    private let haptics: HapticsPlaying
    private let persistsChanges: Bool
    private let logEvent: (BackwordAnalyticsEvent) -> Void

    init(
        puzzle: MidwordPuzzle,
        progress: MidwordProgress? = nil,
        haptics: HapticsPlaying = HapticsEngine(),
        persistsChanges: Bool = true,
        logEvent: @escaping (BackwordAnalyticsEvent) -> Void = { BackwordAnalyticsService.shared.log($0) }
    ) {
        self.puzzle = puzzle
        self.progress = progress ?? (persistsChanges ? MidwordProgress.load(date: puzzle.date) : nil)
            ?? MidwordProgress(date: puzzle.date)
        self.haptics = haptics
        self.persistsChanges = persistsChanges
        self.logEvent = logEvent
    }

    var hasStarted: Bool { progress.startedAt != nil }

    func start(now: Date = Date()) {
        guard !hasStarted, !isComplete else { return }
        progress.start(at: now)
        persist()
        logEvent(.gameStarted(game: .midword))
    }
    var isComplete: Bool { progress.isComplete }
    func completionShareResult(rating: OverallRating, isPro: Bool, progressRecords: [MidwordProgress]? = nil) -> PuzzleShareResult? {
        guard isComplete else { return nil }
        let records = (progressRecords ?? MidwordProgress.loadAll()).filter { $0.date != puzzle.date } + [progress]
        return .midword(
            puzzle: puzzle, progress: progress,
            history: MidwordStatsHistory.make(rating: rating, progressRecords: records),
            rating: rating, isPro: isPro
        )
    }
    var gameExplainer: String {
        if progress.isWon {
            let count = progress.guesses.count
            return "Solved in \(count) \(count == 1 ? "guess" : "guesses")..."
        }
        if progress.isFailed && !progress.isGaveUp { return "Not this time, the answer was..." }
        return progress.isGaveUp ? "You gave up,\nthe answer was..." : "Find the link that ends the top word and starts the bottom word to make 2 new words"
    }
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

    func giveUp(now: Date = Date()) {
        guard hasStarted, !isComplete else { return }
        progress.giveUp(at: now)
        input = ""
        message = nil
        haptics.play(.backwordGameLost)
        persist()
        logCompletion()
    }

    func submitGuess(now: Date = Date(), isValidWord: (String) -> Bool = WordValidator.isValidEnglishWord) {
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
        progress.submit(input, for: puzzle, at: now)
        if progress.isWon {
            haptics.play(.backwordGameWon)
        } else if progress.isFailed {
            haptics.play(.backwordGameLost)
        } else {
            haptics.play(.backwordGuessIncorrect)
        }
        input = ""
        message = nil
        persist()
        if isComplete { logCompletion() }
    }

    private func persist() {
        if persistsChanges { progress.save() }
    }

    private func logCompletion() {
        guard let completedAt = progress.completedAt else { return }
        logEvent(.gameCompleted(
            game: .midword,
            outcome: progress.isWon ? .won : .failed,
            releaseDay: ContentReleaseCalendar(now: completedAt).dailyDateString == puzzle.date,
            score: progress.releaseDateScore,
            durationSeconds: progress.elapsedSecondsAtCompletion.map { TimeInterval($0) }
        ))
    }
}
