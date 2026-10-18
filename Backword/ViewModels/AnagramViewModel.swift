import Combine
import Foundation

@MainActor
final class AnagramViewModel: ObservableObject {
    let puzzle: AnagramPuzzle
    @Published private(set) var progress: AnagramProgress?
    private let persistsChanges: Bool

    init(puzzle: AnagramPuzzle, initialProgress: AnagramProgress? = nil, persistsChanges: Bool = true) {
        self.puzzle = puzzle
        self.persistsChanges = persistsChanges
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
        BackwordAnalyticsService.shared.log(.gameStarted(game: .anagram))
    }

    func place(_ tileID: Int, now: Date = Date()) {
        guard var next = progress else { return }
        let priorOutcome = next.outcome
        next.place(tileID, in: puzzle, now: now)
        progress = next
        persist()
        if priorOutcome == nil, next.outcome != nil { logCompletion(next) }
    }

    func undo(now: Date = Date()) {
        guard var next = progress else { return }
        next.undo(now: now)
        progress = next
        persist()
    }

    func restart(now: Date = Date()) {
        guard var next = progress else { return }
        next.restart(now: now)
        progress = next
        persist()
    }

    func shuffle(now: Date = Date()) {
        guard var next = progress else { return }
        var order = next.availableTileIDs
        order.shuffle()
        if order == next.availableTileIDs && order.count > 1 {
            order.append(order.removeFirst())
        }
        next.shuffle(using: order, in: puzzle, now: now)
        progress = next
        persist()
    }

    func revealHint(source: AnagramProgress.HintSource, now: Date = Date()) {
        guard var next = progress else { return }
        next.revealHint(in: puzzle, source: source, now: now)
        progress = next
        persist()
    }

    func giveUp(now: Date = Date()) {
        guard var next = progress, !next.isComplete else { return }
        next.giveUp(now: now)
        progress = next
        persist()
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
