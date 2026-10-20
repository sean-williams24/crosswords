import Combine
import Foundation

@MainActor
final class AnagramViewModel: ObservableObject {
    let puzzle: AnagramPuzzle
    @Published private(set) var progress: AnagramProgress?
    private let persistsChanges: Bool
    private let haptics: HapticsPlaying

    init(
        puzzle: AnagramPuzzle,
        initialProgress: AnagramProgress? = nil,
        persistsChanges: Bool = true,
        haptics: HapticsPlaying = HapticsEngine()
    ) {
        self.puzzle = puzzle
        self.persistsChanges = persistsChanges
        self.haptics = haptics
        let saved = initialProgress ?? (persistsChanges ? AnagramProgress.load(date: puzzle.date) : nil)
        progress = saved.flatMap { $0.isValid(for: puzzle) ? $0 : nil }
        progress?.avoidLeadingAnswerLetter(in: puzzle)
    }

    var canStart: Bool { progress == nil }
    var availableTileIDs: [Int] { progress?.availableTileIDs ?? [] }
    var canUndo: Bool { progress?.canUndo ?? false }
    var canRestart: Bool { progress?.canRestart ?? false }
    var canHint: Bool { progress.map { !$0.hintUsed && !$0.isComplete } ?? false }

    func completionShareResult(
        rating: OverallRating, isPro: Bool, progressRecords: [AnagramProgress]? = nil
    ) -> PuzzleShareResult? {
        guard let progress, progress.isComplete else { return nil }
        let records = (progressRecords ?? AnagramProgress.loadAll())
            .filter { $0.date != puzzle.date } + [progress]
        return PuzzleShareResult.anagram(
            completion: AnagramCompletion(puzzle: puzzle, progress: progress),
            history: AnagramStatsHistory.make(rating: rating, progressRecords: records),
            rating: rating,
            isPro: isPro
        )
    }

    func start(now: Date = Date()) {
        guard progress == nil else { return }
        progress = AnagramProgress(puzzle: puzzle, now: now)
        persist()
        haptics.play(.letterEntered)
        BackwordAnalyticsService.shared.log(.gameStarted(game: .anagram))
    }

    func place(_ tileID: Int, now: Date = Date()) {
        guard var next = progress else { return }
        let priorOutcome = next.outcome
        next.place(tileID, in: puzzle, now: now)
        guard next.placedTileIDs != progress?.placedTileIDs else { return }
        progress = next
        persist()
        if next.outcome == .solved {
            haptics.play(.backwordGameWon)
        } else if next.displayedAnswer(for: puzzle) != nil {
            haptics.play(.backwordGuessIncorrect)
        } else {
            haptics.play(.letterEntered)
        }
        if priorOutcome == nil, next.outcome != nil { logCompletion(next) }
    }

    func undo(now: Date = Date()) {
        guard var next = progress, next.canUndo else { return }
        next.undo(now: now)
        progress = next
        persist()
        haptics.play(.letterEntered)
    }

    func restart(now: Date = Date()) {
        guard var next = progress, next.canRestart else { return }
        next.restart(now: now)
        progress = next
        persist()
        haptics.play(.letterEntered)
    }

    func shuffle(now: Date = Date()) {
        guard var next = progress, !next.isComplete else { return }
        var order = next.availableTileIDs
        order.shuffle()
        if order == next.availableTileIDs && order.count > 1 {
            order.append(order.removeFirst())
        }
        next.shuffle(using: order, in: puzzle, now: now)
        guard next.trayOrder != progress?.trayOrder else { return }
        progress = next
        persist()
        haptics.play(.clueNavigated)
    }

    func revealHint(source: AnagramProgress.HintSource, now: Date = Date()) {
        guard var next = progress, !next.hintUsed, !next.isComplete else { return }
        next.revealHint(in: puzzle, source: source, now: now)
        guard next.hintUsed else { return }
        progress = next
        persist()
        haptics.play(.hintUsed)
    }

    func giveUp(now: Date = Date()) {
        guard var next = progress, !next.isComplete else { return }
        next.giveUp(now: now)
        progress = next
        persist()
        haptics.play(.backwordGameLost)
        logCompletion(next)
    }

    func reload() {
        guard persistsChanges else { return }
        progress = AnagramProgress.load(date: puzzle.date).flatMap {
            $0.isValid(for: puzzle) ? $0 : nil
        }
        progress?.avoidLeadingAnswerLetter(in: puzzle)
    }

    private func persist() {
        guard persistsChanges else { return }
        guard let progress else { return }
        progress.save()
        #if DEBUG
        if puzzle.date == "review" { return }
        #endif
        ProgressCloudSync.shared.scheduleUpload(progress)
    }

    private func logCompletion(_ progress: AnagramProgress) {
        BackwordAnalyticsService.shared.log(.gameCompleted(
            game: .anagram,
            outcome: progress.outcome == .solved ? .solved : .gaveUp,
            releaseDay: progress.releaseDateScore > 0,
            score: progress.releaseDateScore,
            durationSeconds: TimeInterval(progress.elapsedSecondsAtCompletion ?? 0)
        ))
    }
}
