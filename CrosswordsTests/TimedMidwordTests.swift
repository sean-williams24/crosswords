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
    @Test("Wrong guesses appear newest first and rejected guesses never enter history")
    @MainActor func guessHistory() {
        let model = MidwordViewModel(puzzle: puzzle, haptics: MidwordHistorySilentHaptics(), persistsChanges: false, logEvent: { _ in })
        model.start(now: now)
        #expect(model.previousGuessIndices.isEmpty)
        for guess in ["PAGE", "WORD"] {
            for letter in guess { model.enterLetter(letter) }
            model.submitGuess(now: now, isValidWord: { _ in true })
            #expect(model.input.isEmpty)
        }
        #expect(model.previousGuessIndices.map { model.progress.guesses[$0] } == ["WORD", "PAGE"])
        for letter in "WORD" { model.enterLetter(letter) }
        model.submitGuess(now: now, isValidWord: { _ in true })
        #expect(model.message == "Already guessed")
        #expect(model.previousGuessIndices == [1, 0])
        for _ in 0..<4 { model.deleteLetter() }
        for letter in "ZZQX" { model.enterLetter(letter) }
        model.submitGuess(now: now, isValidWord: { _ in false })
        #expect(model.message == "Not in the dictionary")
        #expect(model.previousGuessIndices == [1, 0])
    }

    @Test("Validation messages hide after three seconds without changing the guess", arguments: ["ZZQX", "PAGE"])
    @MainActor func validationMessageExpires(guess: String) async throws {
        var progress = MidwordProgress(date: puzzle.date)
        progress.start(at: now)
        progress.submit("PAGE", for: puzzle, at: now)
        let model = MidwordViewModel(puzzle: puzzle, progress: progress,
            haptics: MidwordHistorySilentHaptics(), persistsChanges: false, logEvent: { _ in })
        for letter in guess { model.enterLetter(letter) }
        model.submitGuess(now: now, isValidWord: { _ in false })
        let expected = guess == "PAGE" ? "Already guessed" : "Not in the dictionary"
        #expect(model.message == expected)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        #expect(model.message == expected)
        try await Task.sleep(nanoseconds: 1_100_000_000)
        #expect(model.message == nil)
        #expect(model.input == guess)
        #expect(model.progress == progress)
    }

    @Test("Repeated validation restarts the dismissal countdown")
    @MainActor func validationMessageRestarts() async throws {
        let model = MidwordViewModel(puzzle: puzzle, haptics: MidwordHistorySilentHaptics(),
            persistsChanges: false, logEvent: { _ in })
        model.start(now: now)
        for letter in "ZZQX" { model.enterLetter(letter) }
        model.submitGuess(now: now, isValidWord: { _ in false })
        try await Task.sleep(nanoseconds: 1_600_000_000)
        model.submitGuess(now: now, isValidWord: { _ in false })
        try await Task.sleep(nanoseconds: 1_600_000_000)
        #expect(model.message == "Not in the dictionary")
        try await Task.sleep(nanoseconds: 1_500_000_000)
        #expect(model.message == nil)
    }

    @Test("Restored solved history excludes canonical and approved answers", arguments: ["NOTE", "PAGE"])
    @MainActor func restoredHistory(answer: String) {
        let game = MidwordPuzzle(id: puzzle.id, date: puzzle.date, puzzleNumber: puzzle.puzzleNumber,
            firstWord: puzzle.firstWord, secondWord: puzzle.secondWord, answer: puzzle.answer, alternatives: ["PAGE"])
        var progress = MidwordProgress(date: game.date)
        progress.start(at: now)
        progress.submit("WORD", for: game, at: now)
        progress.submit(answer, for: game, at: now)
        let model = MidwordViewModel(puzzle: game, progress: progress, haptics: MidwordHistorySilentHaptics(), persistsChanges: false, logEvent: { _ in })
        #expect(model.isComplete)
        #expect(model.previousGuessIndices == [0])
    }

    @Test("Giving up keeps all previous wrong guesses")
    @MainActor func givenUpHistory() {
        var progress = MidwordProgress(date: puzzle.date)
        progress.start(at: now)
        progress.submit("WORD", for: puzzle, at: now)
        let model = MidwordViewModel(puzzle: puzzle, progress: progress, haptics: MidwordHistorySilentHaptics(), persistsChanges: false, logEvent: { _ in })
        model.giveUp(now: now)
        #expect(model.previousGuessIndices == [0])
        #expect(model.progress.guesses == ["WORD"])
    }

}


private final class MidwordHistorySilentHaptics: HapticsPlaying {
    func play(_ type: HapticsEngine.HapticType) {}
}
