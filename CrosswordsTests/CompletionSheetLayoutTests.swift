import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Completion sheet initial layout")
struct CompletionSheetLayoutTests {
    @Test("Midword lays out its history before the answer animation starts",
          arguments: [false, true], [false, true])
    func midwordHistoryIsPresentImmediately(won: Bool, reduceMotion: Bool) throws {
        let puzzle = MidwordPuzzle(
            id: "layout", date: "2026-10-20", puzzleNumber: 20,
            firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: []
        )
        var progress = MidwordProgress(date: puzzle.date)
        progress.guesses = won ? ["NOTE"] : ["MORE", "SOME", "TONE", "NAME", "WORD"]
        progress.won = won
        progress.completedAt = .now

        func sheet(rows: [MidwordStatsHistoryRow]) -> some View {
            MidwordStatsView(
                puzzle: puzzle, progress: progress, showsCompletion: true,
                previewHistory: MidwordStatsHistory(
                    rows: rows, currentStreak: 0, bestStreak: 0,
                    totalSolved: 0, guessDistribution: [:]
                )
            )
        }
        let rows = (0..<14).map { index in
            MidwordStatsHistoryRow(
                dateStr: "row-\(index)", date: .now, isToday: false,
                score: 0, guessCount: nil, outcome: .unplayed
            )
        }
        let empty = try initialScrollSize(sheet(rows: []), reduceMotion: reduceMotion)
        let populated = try initialScrollSize(sheet(rows: rows), reduceMotion: reduceMotion)

        // This synchronous measurement never waits for any reveal task or delay.
        #expect(populated.height > empty.height + 14 * 30)
        #expect(populated.width <= 390.5)
    }

    @Test("Anagram lays out its history before the answer animation starts",
          arguments: [AnagramProgress.Outcome.solved, .gaveUp], [false, true])
    func anagramHistoryIsPresentImmediately(outcome: AnagramProgress.Outcome, reduceMotion: Bool) throws {
        let puzzle = AnagramPuzzle(
            id: "layout", date: "2026-10-20", puzzleNumber: 20, schemaVersion: 1,
            answer: "TRIANGLE", acceptedAnswers: [], initialScramble: "RAGTLINE"
        )
        var progress = AnagramProgress(puzzle: puzzle)
        progress.outcome = outcome
        progress.completedAt = .now
        progress.elapsedSecondsAtCompletion = 45
        let completion = AnagramCompletion(puzzle: puzzle, progress: progress)

        func sheet(rows: [AnagramStatsHistoryRow]) -> some View {
            AnagramStatsView(
                previewHistory: AnagramStatsHistory(
                    rows: rows, currentStreak: 0, bestStreak: 0,
                    totalSolved: 0, averageSolveTime: "—"
                ),
                completion: completion
            )
        }
        let rows = (0..<14).map { index in
            AnagramStatsHistoryRow(
                dateStr: "row-\(index)", date: .now, isToday: false,
                score: 0, solveTime: nil, outcome: .unplayed
            )
        }
        let empty = try initialScrollSize(sheet(rows: []), reduceMotion: reduceMotion)
        let populated = try initialScrollSize(sheet(rows: rows), reduceMotion: reduceMotion)

        #expect(populated.height > empty.height + 14 * 30)
        #expect(populated.width <= 390.5)
    }

    private func initialScrollSize<Content: View>(_ content: Content, reduceMotion: Bool) throws -> CGSize {
        let host = UIHostingController(rootView: content
            .environmentObject(OverallRatingService(rating: OverallRating()))
            .environmentObject(StoreService())
            .environment(\.accessibilityReduceMotion, reduceMotion)
            .environment(\.dynamicTypeSize, .large)
        )
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return try #require(scrollView(in: host.view)).contentSize
    }

    private func scrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
    }
}
