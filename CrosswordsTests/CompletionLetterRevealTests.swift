import Testing
@testable import Backword

@MainActor
@Suite("Completion letter haptics")
struct CompletionLetterRevealTests {
    @Test("Every Anagram letter reveal plays the same impact as Backword", arguments: [3, 8])
    func oneHapticPerLetter(letterCount: Int) async {
        let haptics = HapticsSpy()
        var revealedSteps: [Int] = []
        let finished = await CompletionLetterReveal.run(
            steps: AnagramCompletionAnimation.revealSteps(letterCount: letterCount),
            interval: 0, haptics: haptics
        ) { step in
            // The previous letter's impact has happened before the next reveal.
            #expect(haptics.played.count == step - 1)
            revealedSteps.append(step)
        }

        #expect(finished)
        #expect(revealedSteps == Array(1...letterCount))
        #expect(haptics.played == Array(repeating: .backwordCompletionLetterRevealed, count: letterCount))
    }

    @Test("Dismissing during a reveal prevents subsequent letters and impacts")
    func cancellationStopsHaptics() async {
        let haptics = HapticsSpy()
        var revealedSteps: [Int] = []
        let task = Task { @MainActor in
            await CompletionLetterReveal.run(
                steps: 1..<9, interval: 0, haptics: haptics
            ) { step in
                revealedSteps.append(step)
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        let finished = await task.value

        #expect(!finished)
        #expect(revealedSteps == [1])
        #expect(haptics.played == [.backwordCompletionLetterRevealed])
    }

    @Test("A cancelled presentation plays no impacts")
    func alreadyCancelled() async {
        let haptics = HapticsSpy()
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await CompletionLetterReveal.run(
                steps: 1..<9, interval: 0, haptics: haptics
            ) { _ in
                Issue.record("A cancelled presentation must not reveal a letter")
            }
        }
        #expect(await task.value == false)
        #expect(haptics.played.isEmpty)
    }
}

private final class HapticsSpy: HapticsPlaying {
    var played: [HapticsEngine.HapticType] = []

    func play(_ type: HapticsEngine.HapticType) {
        played.append(type)
    }
}
