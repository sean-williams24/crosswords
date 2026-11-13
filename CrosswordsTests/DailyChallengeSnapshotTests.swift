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
        #expect(snapshot.possiblePoints == 20)
    }

    @Test("Today's points combine all four games, including an unfinished crossword")
    func combinedPoints() {
        var backword = BackwordProgress(date: date)
        backword.guesses = ["CASTLE", "PUZZLE"]
        backword.wonFlag = true
        backword.completedAt = now
        var crossword = DailyChallengeFixtures.crossword()
        crossword.completedClueIds = [1, 2]
        var anagram = AnagramProgress(puzzle: DailyChallengeFixtures.anagram, now: now)
        anagram.finish(.solved, now: now.addingTimeInterval(65))
        var midword = MidwordProgress(date: date)
        midword.completedAt = now
        midword.won = true
        midword.releaseDateScore = 2
        let snapshot = DailyChallengeSnapshot(
            date: date, backword: backword, crosswords: [crossword], anagram: anagram, midword: midword
        )
        #expect(snapshot.games.map(\.earnedPoints) == [4, 3, 3, 2])
        #expect(snapshot.earnedPoints == 12)
        #expect(snapshot.possiblePoints == 20)
        #expect(snapshot.finishedCount == 3)
        #expect(!snapshot.isComplete)
    }

    @Test("A perfect day earns all twenty points")
    func perfectPoints() {
        var backword = BackwordProgress(date: date)
        backword.guesses = ["PUZZLE"]
        backword.wonFlag = true
        backword.completedAt = now
        var crossword = DailyChallengeFixtures.crossword()
        crossword.completedClueIds = [1, 2, 3, 4]
        crossword.completedAt = now
        var anagram = AnagramProgress(puzzle: DailyChallengeFixtures.anagram, now: now)
        anagram.finish(.solved, now: now)
        var midword = MidwordProgress(date: date)
        midword.completedAt = now
        midword.won = true
        midword.releaseDateScore = 5
        let snapshot = DailyChallengeSnapshot(
            date: date, backword: backword, crosswords: [crossword], anagram: anagram, midword: midword
        )
        #expect(snapshot.earnedPoints == snapshot.possiblePoints)
        #expect(snapshot.isComplete)
    }

    @Test("Crossword points follow completion thresholds and hint penalties",
          arguments: [0, 1, 2, 3, 4])
    func crosswordPoints(completed: Int) {
        var crossword = DailyChallengeFixtures.crossword()
        crossword.completedClueIds = Set(0..<completed)
        #expect(DailyChallengeSnapshot(date: date, crosswords: [crossword]).earnedPoints
                == [0, 2, 3, 4, 5][completed])
        crossword.hintsUsed = 3
        #expect(DailyChallengeSnapshot(date: date, crosswords: [crossword]).earnedPoints
                == [0, 1, 2, 3, 4][completed])
        crossword.hintsUsed = 30
        #expect(DailyChallengeSnapshot(date: date, crosswords: [crossword]).earnedPoints == 0)
    }

    @Test("Giving up the crossword never scores the revealed answers")
    func crosswordGiveUpPoints() {
        var crossword = DailyChallengeFixtures.crossword()
        crossword.completedClueIds = [1, 2, 3, 4]
        crossword.gaveUpAt = now
        crossword.gaveUpScore = 2
        crossword.releaseDateScore = 3
        #expect(DailyChallengeSnapshot(date: date, crosswords: [crossword]).earnedPoints == 2)
        crossword.gaveUpScore = nil
        #expect(DailyChallengeSnapshot(date: date, crosswords: [crossword]).earnedPoints == 3)
    }

    @Test("Saved scores remain available without downloaded crossword content or clue counts")
    func offlinePoints() {
        var crossword = DailyChallengeFixtures.crossword()
        crossword.totalClues = nil
        crossword.releaseDateScore = 4
        let snapshot = DailyChallengeSnapshot(date: date, crosswords: [crossword])
        #expect(snapshot.earnedPoints == 4)
        #expect(snapshot.possiblePoints == 20)
        #expect(DailyChallengeSnapshot(date: date).earnedPoints == 0)
    }

    @Test("Backword and Midword fill by accepted guess without finishing early",
          arguments: [0, 1, 2, 3, 4, 5])
    func guessProgress(guesses: Int) {
        var backword = BackwordProgress(date: date)
        backword.guesses = Array(repeating: "CASTLE", count: guesses)
        var midword = MidwordProgress(date: date)
        midword.guesses = Array(repeating: "NOTE", count: guesses)
        let snapshot = DailyChallengeSnapshot(date: date, backword: backword, midword: midword)
        let expected = guesses == 0 ? nil : Double(min(guesses, 4)) / 5
        #expect(snapshot[.backword].fillFraction == expected)
        #expect(snapshot[.midword].fillFraction == nil)
        #expect(snapshot[.backword].isFinished == false)
        #expect(snapshot[.midword].isFinished == false)
        #expect(snapshot[.backword].accessibilityLabel.contains("\(guesses) of 5 guesses used") == (guesses > 0))
        midword.completedAt = now
        backword.completedAt = now
        let finished = DailyChallengeSnapshot(date: date, backword: backword, midword: midword)
        #expect(finished[.backword].fillFraction == nil)
        #expect(finished[.midword].fillFraction == nil)
        #expect(finished[.backword].isFinished)
        #expect(finished[.midword].isFinished)
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
        #expect(snapshot[.backword].fillFraction == 0.2)
        #expect(snapshot[.midword].fillFraction == nil)
        #expect(snapshot.finishedCount == 0)
    }

    @Test("Hinted Backword and started Anagram are in progress")
    func startedGames() {
        var backword = BackwordProgress(date: date)
        backword.clueRevealed = true
        let anagram = AnagramProgress(puzzle: DailyChallengeFixtures.anagram, now: now)
        let snapshot = DailyChallengeSnapshot(date: date, backword: backword, anagram: anagram, now: now)
        #expect(snapshot[.backword].state == .inProgress)
        #expect(snapshot[.anagram].state == .inProgress)
        #expect(snapshot[.anagram].fillFraction == 0)
        #expect(snapshot.nextAnagramProgressTick == now.addingTimeInterval(30))
    }

    @Test("Anagram advances every 30 seconds and stays below full before completion",
          arguments: [0, 29, 30, 59, 60, 179, 180, 360])
    func anagramTimer(seconds: Int) {
        let progress = AnagramProgress(puzzle: DailyChallengeFixtures.anagram, now: now)
        let snapshot = DailyChallengeSnapshot(
            date: date, anagram: progress, now: now.addingTimeInterval(TimeInterval(seconds))
        )
        let intervals = min(seconds / 30, 6)
        #expect(snapshot[.anagram].state == .inProgress)
        #expect(snapshot[.anagram].fillFraction == Double(intervals) / 7)
        #expect(snapshot.nextAnagramProgressTick == (intervals < 6
            ? now.addingTimeInterval(TimeInterval((intervals + 1) * 30)) : nil))
        #expect(snapshot[.anagram].accessibilityLabel.contains("\(intervals) 30-second intervals elapsed"))
    }

    @Test("Finishing Anagram fills its marker and stops the Home timer")
    func completedAnagramTimer() {
        var progress = AnagramProgress(puzzle: DailyChallengeFixtures.anagram, now: now)
        progress.giveUp(now: now.addingTimeInterval(45))
        let snapshot = DailyChallengeSnapshot(
            date: date, anagram: progress, now: now.addingTimeInterval(300)
        )
        #expect(snapshot[.anagram].state == .finished(won: false))
        #expect(snapshot[.anagram].fillFraction == nil)
        #expect(snapshot.nextAnagramProgressTick == nil)
    }

    @Test("Crossword exposes clamped measurable progress but remains unfinished")
    func crosswordProgress() {
        var progress = DailyChallengeFixtures.crossword()
        progress.completedClueIds = [1, 2]
        var snapshot = DailyChallengeSnapshot(date: date, crosswords: [progress])
        #expect(snapshot[.crossword].state == .inProgress)
        #expect(snapshot[.crossword].fillFraction == 0.5)
        #expect(snapshot.finishedCount == 0)
        progress.totalClues = 1
        snapshot = DailyChallengeSnapshot(date: date, crosswords: [progress])
        #expect(snapshot[.crossword].fillFraction == 2.0 / 3.0)
        #expect(snapshot[.crossword].state == .inProgress)
        progress.totalClues = 0
        #expect(DailyChallengeSnapshot(date: date, crosswords: [progress])[.crossword].fillFraction == nil)
    }

    @Test("A loaded grid overrides stale saved clue counts before the last answer")
    func loadedCrosswordClueCount() {
        var progress = DailyChallengeFixtures.crossword()
        progress.totalClues = 3
        progress.completedClueIds = [1, 2, 3]
        let clues = (1...4).map { id in
            Clue(id: id, direction: .across, number: id, text: "Clue", hint: "Hint",
                 answer: "A", startRow: 0, startCol: 0, length: 1)
        }
        let puzzle = Puzzle(id: progress.puzzleId, puzzleNumber: 1, date: date,
                            size: 1, cells: [], clues: clues)

        let snapshot = DailyChallengeSnapshot(date: date, crosswords: [progress], dailyPuzzle: puzzle)
        #expect(snapshot[.crossword].state == .inProgress)
        #expect(snapshot[.crossword].fillFraction == 0.75)
        #expect(snapshot.finishedCount == 0)
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
        #expect(snapshot.earnedPoints == 0)
        #expect(snapshot.games.allSatisfy { $0.state == .finished(won: false) })
        #expect(snapshot.games.allSatisfy { $0.accessibilityLabel.contains("Finished without a win") })
    }

    @Test("An older release completed today and weekly crosswords are excluded")
    func excludedReleases() {
        var backword = BackwordProgress(date: "2026-11-06")
        backword.guesses = ["PUZZLE"]
        backword.wonFlag = true
        backword.completedAt = now
        var weekly = DailyChallengeFixtures.crossword()
        weekly.isWeekly = true
        weekly.completedAt = now
        weekly.releaseDateScore = 5
        var archive = DailyChallengeFixtures.crossword()
        archive.puzzleDate = "2026-11-06"
        archive.completedAt = now
        archive.releaseDateScore = 5
        var midword = MidwordProgress(date: "2026-11-06")
        midword.completedAt = now
        midword.releaseDateScore = 5
        var anagram = AnagramProgress(puzzle: DailyChallengeFixtures.anagram, now: now)
        anagram.finish(.solved, now: now)
        let snapshot = DailyChallengeSnapshot(date: date, backword: backword, crosswords: [weekly, archive])
        #expect(snapshot.finishedCount == 0)
        #expect(snapshot.earnedPoints == 0)
        #expect(snapshot.games.allSatisfy { $0.state == .notStarted })
        #expect(DailyChallengeSnapshot(date: "2026-11-08", anagram: anagram, midword: midword).earnedPoints == 0)
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
            anagram: finished >= 3 ? anagram : nil, midword: midword, now: at
        )
    }
}
