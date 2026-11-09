import Combine
import Foundation
import Testing
@testable import Backword

@MainActor
@Suite("Daily challenge celebration sequence")
struct DailyChallengeCelebrationViewModelTests {
    @Test("Each game appears before its points and the total appears last")
    func fullSequence() async {
        var delays: [Duration] = []
        let model = DailyChallengeCelebrationViewModel { delays.append($0) }
        var steps: [Int] = []
        let observation = model.$step.sink { steps.append($0) }
        await model.reveal(reduceMotion: false)
        withExtendedLifetime(observation) {
            #expect(steps == [0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        }
        #expect(delays == [.milliseconds(300), .milliseconds(300), .milliseconds(450),
                           .milliseconds(300), .milliseconds(450), .milliseconds(300),
                           .milliseconds(450), .milliseconds(300), .milliseconds(450)])
        #expect(DailyChallengeGame.allCases.allSatisfy { model.showsGame($0) && model.showsPoints($0) })
        #expect(model.showsTotal)
    }

    @Test("Every intermediate stage reveals only the expected game and point labels",
          arguments: Array(0...8))
    func intermediateStages(step: Int) async {
        var pauses = 0
        let model = DailyChallengeCelebrationViewModel { _ in
            pauses += 1
            if pauses == step + 1 { throw CancellationError() }
        }
        await model.reveal(reduceMotion: false)
        #expect(model.step == step)
        for (index, game) in DailyChallengeGame.allCases.enumerated() {
            #expect(model.showsGame(game) == (step >= index * 2 + 1))
            #expect(model.showsPoints(game) == (step >= index * 2 + 2))
        }
        #expect(!model.showsTotal)
    }

    @Test("Reduce Motion shows the complete result immediately without waiting")
    func reduceMotion() async {
        var pauses = 0
        let model = DailyChallengeCelebrationViewModel { _ in pauses += 1 }
        await model.reveal(reduceMotion: true)
        #expect(pauses == 0)
        #expect(model.showsTotal)
        #expect(DailyChallengeGame.allCases.allSatisfy { model.showsGame($0) && model.showsPoints($0) })
    }

    @Test("Cancelling the view task stops the sequence before any further reveals")
    func cancellation() async {
        let model = DailyChallengeCelebrationViewModel { _ in }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await model.reveal(reduceMotion: false)
        }
        await task.value
        #expect(model.step == 0)
        #expect(!model.showsTotal)
    }
}
