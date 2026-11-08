import Foundation
import Testing
@testable import Backword

@Suite("Daily challenge progress")
struct DailyChallengeSnapshotTests {
    private let date = DailyChallengeFixtures.date
    private let now = DailyChallengeFixtures.now

    @Test("The four games keep a fixed order and denominator", arguments: [0, 1, 2, 3, 4])
    func counts(finished: Int) {
        let snapshot = DailyChallengeFixtures.snapshot(finished: finished)
        #expect(snapshot.games.map(\.game) == [.backword, .crossword, .anagram, .midword])
        #expect(snapshot.finishedCount == finished)
        #expect(snapshot.isComplete == (finished == 4))
    }

    @Test("Unstarted records do not manufacture progress from guesses remaining")
    func unstartedAndGuesses() {
        var backword = BackwordProgress(date: date)
        var midword = MidwordProgress(date: date)
        var snapshot = DailyChallengeSnapshot(date: date, backword: backword, midword: midword)
        #expect(snapshot.games.allSatisfy { $0.state == .notStarted })
        backword.guesses = ["CASTLE"]
        midword.guesses = ["NOTE", "BOOK"]
        snapshot = DailyChallengeSnapshot(date: date, backword: backword, midword: midword)
        #expect(snapshot[.backword].state == .inProgress)
        #expect(snapshot[.midword].state == .inProgress)
        #expect(snapshot.games.allSatisfy { $0.crosswordFraction == nil })
        #expect(snapshot.finishedCount == 0)
    }

    @Test("Hinted Backword and started Anagram are in progress")
    func startedGames() {
        var backword = BackwordProgress(date: date)
        backword.clueRevealed = true
        let anagram = AnagramProgress(puzzle: DailyChallengeFixtures.anagram, now: now)
        let snapshot = DailyChallengeSnapshot(date: date, backword: backword, anagram: anagram)
        #expect(snapshot[.backword].state == .inProgress)
        #expect(snapshot[.anagram].state == .inProgress)
        #expect(snapshot[.anagram].crosswordFraction == nil)
    }

    @Test("Crossword exposes clamped measurable progress but remains unfinished")
    func crosswordProgress() {
        var progress = DailyChallengeFixtures.crossword()
        progress.completedClueIds = [1, 2]
        var snapshot = DailyChallengeSnapshot(date: date, crosswords: [progress])
        #expect(snapshot[.crossword].state == .inProgress)
        #expect(snapshot[.crossword].crosswordFraction == 0.5)
        #expect(snapshot.finishedCount == 0)
        progress.totalClues = 1
        snapshot = DailyChallengeSnapshot(date: date, crosswords: [progress])
        #expect(snapshot[.crossword].crosswordFraction == 1)
        progress.totalClues = 0
        #expect(DailyChallengeSnapshot(date: date, crosswords: [progress])[.crossword].crosswordFraction == nil)
    }

    @Test("Every loss and give-up counts as a finished game")
    func failedFinishes() {
        var backword = BackwordProgress(date: date)
        backword.completedAt = now
        var crossword = DailyChallengeFixtures.crossword()
        crossword.gaveUpAt = now
        var anagram = AnagramProgress(puzzle: DailyChallengeFixtures.anagram, now: now)
        anagram.giveUp(now: now)
        var midword = MidwordProgress(date: date)
        midword.completedAt = now
        let snapshot = DailyChallengeSnapshot(
            date: date, backword: backword, crosswords: [crossword], anagram: anagram, midword: midword
        )
        #expect(snapshot.isComplete)
        #expect(snapshot.games.allSatisfy { $0.state == .finished(won: false) })
        #expect(snapshot.games.allSatisfy { $0.accessibilityLabel.contains("Finished without a win") })
    }

    @Test("An older release completed today and weekly crosswords are excluded")
    func excludedReleases() {
        var backword = BackwordProgress(date: "2026-11-06")
        backword.completedAt = now
        var weekly = DailyChallengeFixtures.crossword()
        weekly.isWeekly = true
        weekly.completedAt = now
        var archive = DailyChallengeFixtures.crossword()
        archive.puzzleDate = "2026-11-06"
        archive.completedAt = now
        let snapshot = DailyChallengeSnapshot(date: date, backword: backword, crosswords: [weekly, archive])
        #expect(snapshot.finishedCount == 0)
        #expect(snapshot.games.allSatisfy { $0.state == .notStarted })
    }

    @Test("Explicit release metadata works without downloaded puzzle content")
    func offlineCrossword() {
        var progress = DailyChallengeFixtures.crossword()
        progress.completedAt = now
        #expect(DailyChallengeSnapshot(date: date, crosswords: [progress]).finishedCount == 1)
        progress.puzzleDate = nil
        #expect(DailyChallengeSnapshot(date: date, crosswords: [progress]).finishedCount == 0)
        let puzzle = DailyChallengeFixtures.puzzle
        progress = UserProgress(puzzleId: puzzle.id, size: puzzle.size)
        progress.completedAt = now
        #expect(DailyChallengeSnapshot(date: date, crosswords: [progress], dailyPuzzle: puzzle).finishedCount == 1)
    }
}

enum DailyChallengeFixtures {
    static let date = "2026-11-07"
    static let now = Date(timeIntervalSince1970: 1_794_052_800) // 2026-11-07, 12:00 UTC
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    static var anagram: AnagramPuzzle {
        AnagramPuzzle(id: "anagram", date: date, puzzleNumber: 1, schemaVersion: 1,
                     answer: "TRIANGLE", acceptedAnswers: [], initialScramble: "RAGTLINE")
    }
    static var puzzle: Puzzle {
        Puzzle(id: "crossword", puzzleNumber: 1, date: date, size: 1, cells: [], clues: [])
    }
    static func crossword() -> UserProgress {
        UserProgress(puzzleId: "crossword", size: 1, puzzleDate: date, totalClues: 4, isWeekly: false)
    }
    static func snapshot(finished: Int, at: Date = now) -> DailyChallengeSnapshot {
        var backword = BackwordProgress(date: date)
        if finished >= 1 { backword.completedAt = at; backword.wonFlag = true }
        var crossword = Self.crossword()
        if finished >= 2 { crossword.completedAt = at }
        var anagram = AnagramProgress(puzzle: Self.anagram, now: at)
        if finished >= 3 { anagram.finish(.solved, now: at) }
        var midword = MidwordProgress(date: date)
        if finished >= 4 { midword.completedAt = at; midword.won = true }
        return DailyChallengeSnapshot(
            date: date, backword: backword, crosswords: finished >= 2 ? [crossword] : [],
            anagram: finished >= 3 ? anagram : nil, midword: midword
        )
    }
}
