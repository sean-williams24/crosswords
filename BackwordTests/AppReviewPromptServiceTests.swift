import Foundation
import Testing
@testable import Backword

@MainActor
@Suite("App review prompt service")
struct AppReviewPromptServiceTests {
    @Test("First request happens after third eligible crossword completion")
    func firstRequestAfterThirdEligibleCompletion() {
        let harness = Harness()

        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-1", gaveUp: false)
        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-2", gaveUp: false)

        #expect(harness.requestCount == 0)

        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-3", gaveUp: false)

        #expect(harness.requestCount == 1)
        #expect(harness.service.loadState().eligibleCompletionCount == 3)
        #expect(harness.service.loadState().completionCountAtLastRequest == 3)
    }

    @Test("Duplicate puzzle IDs are counted only once")
    func duplicatePuzzleIDsAreIgnored() {
        let harness = Harness()

        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-1", gaveUp: false)
        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-1", gaveUp: false)
        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-2", gaveUp: false)
        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-3", gaveUp: false)

        let state = harness.service.loadState()
        #expect(state.eligibleCompletionCount == 3)
        #expect(state.countedPuzzleIds == Set(["daily-1", "daily-2", "daily-3"]))
        #expect(harness.requestCount == 1)
    }

    @Test("Give-up completions do not count")
    func giveUpCompletionsDoNotCount() {
        let harness = Harness()

        harness.service.recordEligibleCrosswordCompletion(puzzleId: "gave-up", gaveUp: true)
        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-1", gaveUp: false)
        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-2", gaveUp: false)

        #expect(harness.service.loadState().eligibleCompletionCount == 2)
        #expect(harness.requestCount == 0)
    }

    @Test("Repeat request requires cooldown and five more completions")
    func repeatRequestRequiresCooldownAndAdditionalCompletions() {
        let harness = Harness(now: Date(timeIntervalSince1970: 0))

        for id in 1...3 {
            harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-\(id)", gaveUp: false)
        }
        #expect(harness.requestCount == 1)

        harness.currentDate = Date(timeIntervalSince1970: 89 * 24 * 60 * 60)
        for id in 4...8 {
            harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-\(id)", gaveUp: false)
        }
        #expect(harness.requestCount == 1)

        harness.currentDate = Date(timeIntervalSince1970: 90 * 24 * 60 * 60)
        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-9", gaveUp: false)

        #expect(harness.requestCount == 2)
        #expect(harness.service.loadState().completionCountAtLastRequest == 9)
    }

    @Test("Repeat request waits for five additional completions after cooldown")
    func repeatRequestRequiresFiveAdditionalCompletions() {
        let harness = Harness(now: Date(timeIntervalSince1970: 0))

        for id in 1...3 {
            harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-\(id)", gaveUp: false)
        }

        harness.currentDate = Date(timeIntervalSince1970: 90 * 24 * 60 * 60)
        for id in 4...7 {
            harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-\(id)", gaveUp: false)
        }

        #expect(harness.requestCount == 1)

        harness.service.recordEligibleCrosswordCompletion(puzzleId: "daily-8", gaveUp: false)

        #expect(harness.requestCount == 2)
    }
}

@MainActor
private final class Harness {
    let userDefaults: UserDefaults
    let stateKey: String
    var currentDate: Date
    var requestCount = 0
    lazy var service = AppReviewPromptService(
        userDefaults: userDefaults,
        stateKey: stateKey,
        calendar: Calendar(identifier: .gregorian),
        now: { [weak self] in self?.currentDate ?? Date() },
        requestReview: { [weak self] in self?.requestCount += 1 }
    )

    init(now: Date = Date(timeIntervalSince1970: 0)) {
        stateKey = "appReviewPromptState-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: "AppReviewPromptServiceTests-\(UUID().uuidString)")!
        currentDate = now
    }
}
