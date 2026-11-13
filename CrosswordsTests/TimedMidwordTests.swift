import Foundation
import Testing
@testable import Backword

@Suite("Timed Midword")
struct TimedMidwordTests {
    let now = Date(timeIntervalSince1970: 1794484800)
    var puzzle: MidwordPuzzle {
        MidwordPuzzle(id: "timed", date: ContentReleaseCalendar(now: now).dailyDateString,
            puzzleNumber: 1, firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: [])
    }

    @Test("Scoring boundaries", arguments: [(0,5),(29,5),(30,4),(59,4),(60,3),(119,3),(120,2),(179,2),(180,1),(3600,1)])
    func scoring(seconds: Int, points: Int) {
        var progress = MidwordProgress(date: puzzle.date)
        progress.start(at: now)
        progress.submit("NOTE", for: puzzle, at: now.addingTimeInterval(Double(seconds)))
        #expect(progress.releaseDateScore == points)
        #expect(progress.elapsedSecondsAtCompletion == seconds)
    }

    @Test("Start is explicit, persists and cannot be reset")
    func startAndReload() throws {
        var progress = MidwordProgress(date: puzzle.date)
        progress.submit("NOTE", for: puzzle, at: now)
        #expect(!progress.isComplete)
        progress.start(at: now)
        let restored = try JSONDecoder().decode(MidwordProgress.self, from: JSONEncoder().encode(progress))
        progress.start(at: now.addingTimeInterval(60))
        #expect(progress.startedAt == now)
        #expect(restored.elapsedSeconds(at: now.addingTimeInterval(60)) == 60)
    }

    @Test("Unlimited guesses and explicit give-up")
    func unlimited() {
        var progress = MidwordProgress(date: puzzle.date)
        progress.start(at: now)
        for guess in ["PAGE", "BOOK", "WORD", "READ", "LINE", "LINK"] {
            progress.submit(guess, for: puzzle, at: now)
        }
        #expect(!progress.isComplete)
        #expect(progress.guesses.count == 6)
        var won = progress
        won.submit("NOTE", for: puzzle, at: now)
        #expect(won.isWon)
        progress.giveUp(at: now.addingTimeInterval(45))
        #expect(progress.isFailed)
        #expect(progress.releaseDateScore == 0)
        #expect(progress.elapsedSecondsAtCompletion == 45)
    }

    @Test("Merges retain the earliest start and first outcome")
    func merge() {
        var early = MidwordProgress(date: puzzle.date)
        early.start(at: now)
        var late = MidwordProgress(date: puzzle.date)
        late.start(at: now.addingTimeInterval(30))
        late.submit("NOTE", for: puzzle, at: now.addingTimeInterval(60))
        let result = MidwordProgress.merged(early, late)
        #expect(result == MidwordProgress.merged(late, early))
        #expect(result.startedAt == now)
        #expect(result.elapsedSecondsAtCompletion == 60)
        #expect(result.releaseDateScore == 3)
        var stale = late
        stale.startedAt = nil
        #expect(MidwordProgress.merged(early, stale) == early)
        #expect(MidwordProgress.merged(stale, early) == early)
        early.giveUp(at: now.addingTimeInterval(20))
        #expect(MidwordProgress.merged(early, late).isFailed)
    }

    @Test("Completed legacy results survive and unfinished legacy games start afresh")
    func legacy() throws {
        let data = Data("{\"date\":\"2026-10-01\",\"guesses\":[\"NOTE\"],\"won\":true,\"completedAt\":1,\"releaseDateScore\":4}".utf8)
        let saved = try JSONDecoder().decode(MidwordProgress.self, from: data)
        #expect(saved.startedAt == nil)
        #expect(saved.formattedCompletionTime == "–")
        var resumed = MidwordProgress(date: saved.date)
        resumed.guesses = ["PAGE"]
        resumed.start(at: now)
        #expect(resumed.guesses == ["PAGE"])
        #expect(MidwordProgress.merged(saved, resumed) == saved)
    }
}
