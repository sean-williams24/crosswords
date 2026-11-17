import Foundation
import Testing
@testable import Backword

@MainActor
@Suite("Midword analytics")
struct MidwordAnalyticsTests {
    private let now = Date(timeIntervalSince1970: 1794484800)

    private func puzzle(archive: Bool = false) -> MidwordPuzzle {
        MidwordPuzzle(
            id: "analytics", date: archive ? "2026-10-01" : ContentReleaseCalendar(now: now).dailyDateString,
            puzzleNumber: 1, firstWord: "BANK", secondWord: "BOOK", answer: "NOTE", alternatives: ["PAGE"]
        )
    }

    @Test("Start is emitted once and unavailable actions emit nothing")
    func startsOnce() {
        let spy = MidwordAnalyticsSpy()
        let model = makeModel(spy: spy)
        model.giveUp(now: now)
        model.submitGuess(now: now)
        #expect(spy.events.isEmpty)
        model.start(now: now)
        model.start(now: now.addingTimeInterval(30))
        #expect(spy.events == [.gameStarted(game: .midword)])
        #expect(model.progress.startedAt == now)
    }

    @Test("Canonical and alternative solves emit one timed completion", arguments: ["NOTE", "PAGE"])
    func solves(answer: String) {
        let spy = MidwordAnalyticsSpy()
        let model = makeModel(spy: spy)
        model.start(now: now)
        enter(answer, into: model)
        model.submitGuess(now: now.addingTimeInterval(90), isValidWord: { _ in false })
        model.submitGuess(now: now.addingTimeInterval(120))
        model.giveUp(now: now.addingTimeInterval(120))
        model.start(now: now.addingTimeInterval(120))

        #expect(spy.events == [
            .gameStarted(game: .midword),
            .gameCompleted(game: .midword, outcome: .won, releaseDay: true, score: 3, durationSeconds: 90)
        ])
    }

    @Test("Give-up reports release date independently of its zero score", arguments: [false, true])
    func givesUp(archive: Bool) {
        let spy = MidwordAnalyticsSpy()
        let model = makeModel(spy: spy, game: puzzle(archive: archive))
        model.start(now: now)
        model.giveUp(now: now.addingTimeInterval(65))
        model.giveUp(now: now.addingTimeInterval(70))
        #expect(spy.events == [
            .gameStarted(game: .midword),
            .gameCompleted(game: .midword, outcome: .failed, releaseDay: !archive, score: 0, durationSeconds: 65)
        ])
    }

    @Test("Archive solves report zero release-day score")
    func archiveSolve() {
        let spy = MidwordAnalyticsSpy()
        let model = makeModel(spy: spy, game: puzzle(archive: true))
        model.start(now: now)
        enter("NOTE", into: model)
        model.submitGuess(now: now.addingTimeInterval(20))
        #expect(spy.events.last == .gameCompleted(
            game: .midword, outcome: .won, releaseDay: false, score: 0, durationSeconds: 20
        ))
    }

    @Test("Incomplete, invalid, duplicate and incorrect guesses emit no completion")
    func nonterminalGuesses() {
        let spy = MidwordAnalyticsSpy()
        let model = makeModel(spy: spy)
        model.start(now: now)
        enter("NO", into: model)
        model.submitGuess(now: now)
        model.deleteLetter()
        model.deleteLetter()
        enter("AAAA", into: model)
        model.submitGuess(now: now, isValidWord: { _ in false })
        for _ in 0..<4 { model.deleteLetter() }
        enter("WORD", into: model)
        model.submitGuess(now: now, isValidWord: { _ in true })
        enter("WORD", into: model)
        model.submitGuess(now: now, isValidWord: { _ in true })
        #expect(model.progress.guesses == ["WORD"])
        #expect(spy.events == [.gameStarted(game: .midword)])
    }

    @Test("Restored games do not replay events", arguments: [false, true])
    func restores(complete: Bool) {
        let spy = MidwordAnalyticsSpy()
        var progress = MidwordProgress(date: puzzle().date)
        progress.start(at: now)
        if complete { progress.submit("NOTE", for: puzzle(), at: now.addingTimeInterval(40)) }
        let model = makeModel(spy: spy, progress: progress)
        model.start(now: now)
        #expect(spy.events.isEmpty)
        if complete {
            model.giveUp(now: now)
            model.submitGuess(now: now)
            #expect(spy.events.isEmpty)
        } else {
            enter("NOTE", into: model)
            model.submitGuess(now: now.addingTimeInterval(70))
            #expect(spy.events == [.gameCompleted(
                game: .midword, outcome: .won, releaseDay: true, score: 3, durationSeconds: 70
            )])
        }
    }

    @Test("Completed legacy games cannot emit a start")
    func legacyCompletion() {
        let spy = MidwordAnalyticsSpy()
        var progress = MidwordProgress(date: puzzle().date)
        progress.completedAt = now
        let model = makeModel(spy: spy, progress: progress)
        model.start(now: now)
        model.giveUp(now: now)
        #expect(spy.events.isEmpty)
    }

    private func makeModel(
        spy: MidwordAnalyticsSpy, game: MidwordPuzzle? = nil, progress: MidwordProgress? = nil
    ) -> MidwordViewModel {
        MidwordViewModel(
            puzzle: game ?? puzzle(), progress: progress, haptics: spy,
            persistsChanges: false, logEvent: { spy.events.append($0) }
        )
    }

    private func enter(_ word: String, into model: MidwordViewModel) {
        for letter in word { model.enterLetter(letter) }
    }
}

private final class MidwordAnalyticsSpy: HapticsPlaying {
    var events: [BackwordAnalyticsEvent] = []
    func play(_ type: HapticsEngine.HapticType) {}
}
