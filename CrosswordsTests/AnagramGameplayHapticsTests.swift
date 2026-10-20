import Foundation
import Testing
@testable import Backword

@MainActor
@Suite("Anagram gameplay haptics")
struct AnagramGameplayHapticsTests {
    private let puzzle = AnagramPuzzle(
        id: "haptics", date: "2026-10-20", puzzleNumber: 20, schemaVersion: 1,
        answer: "TRIANGLE", acceptedAnswers: ["INTEGRAL"], initialScramble: "RAGTLINE"
    )

    @Test("Starting, placing letters, Undo and Restart each play one light impact")
    func editing() {
        let haptics = AnagramGameplayHapticsSpy()
        let model = makeModel(haptics: haptics)
        model.start()
        model.place(0)
        model.place(1)
        model.undo()
        #expect(model.progress?.placementHistory == [0])
        model.restart()

        #expect(model.progress?.placementHistory.isEmpty == true)
        #expect(haptics.played == Array(repeating: .letterEntered, count: 5))
    }

    @Test("Unavailable edits do not play feedback or change progress")
    func ignoredActions() {
        let haptics = AnagramGameplayHapticsSpy()
        let model = makeModel(haptics: haptics)
        model.place(0)
        model.undo()
        model.restart()
        model.shuffle()
        model.revealHint(source: .timePenalty)
        model.giveUp()
        #expect(haptics.played.isEmpty)

        model.start()
        model.place(0)
        haptics.played.removeAll()
        let before = model.progress
        model.start()
        model.place(0)
        model.place(-1)
        model.place(99)
        #expect(model.progress == before)
        #expect(haptics.played.isEmpty)

        model.undo()
        haptics.played.removeAll()
        model.undo()
        model.restart()
        #expect(haptics.played.isEmpty)
    }

    @Test("Shuffle uses soft feedback and Hint uses warning feedback only once")
    func shuffleAndHint() {
        let haptics = AnagramGameplayHapticsSpy()
        let model = makeModel(haptics: haptics)
        model.start()
        haptics.played.removeAll()
        let order = model.progress?.trayOrder
        model.shuffle()
        #expect(model.progress?.trayOrder != order)
        model.revealHint(source: .timePenalty)
        model.revealHint(source: .rewardedAd)
        model.undo()
        model.restart()

        #expect(model.progress?.hintUsed == true)
        #expect(model.progress?.penaltySeconds == 30)
        #expect(haptics.played == [.clueNavigated, .hintUsed])
    }

    @Test("A full incorrect answer uses incorrect feedback and stays editable")
    func incorrectAnswer() {
        let haptics = AnagramGameplayHapticsSpy()
        let model = makeModel(haptics: haptics)
        model.start()
        haptics.played.removeAll()
        for tile in 0..<8 { model.place(tile) }
        #expect(haptics.played == Array(repeating: .letterEntered, count: 7) + [.backwordGuessIncorrect])
        #expect(model.progress?.isComplete == false)
        haptics.played.removeAll()
        model.place(0)
        model.shuffle() // No available tiles to rearrange.
        #expect(haptics.played.isEmpty)
        model.undo()
        #expect(haptics.played == [.letterEntered])
    }

    @Test("Solving uses one win pattern for the final tile", arguments: [
        [3, 0, 5, 1, 6, 2, 4, 7], // TRIANGLE
        [5, 6, 3, 7, 2, 0, 1, 4]  // INTEGRAL
    ])
    func solvedAnswer(tiles: [Int]) {
        let haptics = AnagramGameplayHapticsSpy()
        let model = makeModel(haptics: haptics)
        model.start()
        haptics.played.removeAll()
        for tile in tiles { model.place(tile) }

        #expect(model.progress?.outcome == .solved)
        #expect(haptics.played == Array(repeating: .letterEntered, count: 7) + [.backwordGameWon])
    }

    @Test("Confirmed give-up uses one loss pattern and completed games stay silent",
          arguments: [AnagramProgress.Outcome.solved, .gaveUp])
    func terminalActions(outcome: AnagramProgress.Outcome) {
        let haptics = AnagramGameplayHapticsSpy()
        let model = makeModel(haptics: haptics)
        model.start()
        if outcome == .solved {
            for tile in [3, 0, 5, 1, 6, 2, 4, 7] { model.place(tile) }
        } else {
            haptics.played.removeAll()
            model.giveUp()
            #expect(haptics.played == [.backwordGameLost])
        }
        haptics.played.removeAll()
        let finished = model.progress
        model.place(0)
        model.undo()
        model.restart()
        model.shuffle()
        model.revealHint(source: .timePenalty)
        model.giveUp()
        model.start()
        #expect(haptics.played.isEmpty)
        #expect(model.progress == finished)
    }

    @Test("Restoring saved progress does not replay gameplay haptics")
    func restoration() {
        let haptics = AnagramGameplayHapticsSpy()
        var saved = AnagramProgress(puzzle: puzzle)
        saved.place(0, in: puzzle)
        let model = AnagramViewModel(
            puzzle: puzzle, initialProgress: saved, persistsChanges: false, haptics: haptics
        )
        model.reload()
        #expect(haptics.played.isEmpty)
        model.undo()
        #expect(haptics.played == [.letterEntered])
    }

    private func makeModel(haptics: HapticsPlaying) -> AnagramViewModel {
        AnagramViewModel(puzzle: puzzle, persistsChanges: false, haptics: haptics)
    }
}

private final class AnagramGameplayHapticsSpy: HapticsPlaying {
    var played: [HapticsEngine.HapticType] = []

    func play(_ type: HapticsEngine.HapticType) {
        played.append(type)
    }
}
