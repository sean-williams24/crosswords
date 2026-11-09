import Foundation
import Testing
@testable import Backword

@MainActor
@Suite("Home daily challenge lifecycle")
struct HomeDailyChallengeViewModelTests {
    @Test("Any final game celebrates only on returning Home, even when the day earned zero points",
          arguments: DailyChallengeGame.allCases)
    func finalGameReturn(game: DailyChallengeGame) {
        let fixture = Fixture()
        fixture.progress.snapshot = failedDay(lastGame: game, finishLast: false)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        fixture.model.beginGame(game, accountID: nil, dailyPuzzle: nil)
        fixture.clock.now = fixture.clock.now.addingTimeInterval(1)
        fixture.progress.snapshot = failedDay(lastGame: game, finishLast: true, at: fixture.clock.now)

        // Home's content and path refresh before its return transition settles.
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        #expect(fixture.model.snapshot.isComplete)
        #expect(fixture.model.snapshot.earnedPoints == 0)
        #expect(fixture.celebrations.keys.isEmpty)
        #expect(!fixture.model.isCelebrating)
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        #expect(fixture.haptics.played.isEmpty)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)

        // Feedback begins when the returned Home content becomes available.
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        #expect(fixture.model.celebrationID == 1)
        #expect(fixture.haptics.played == [.wordCompleted])
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        #expect(fixture.model.celebrationID == 1)
        #expect(fixture.haptics.played.count == 1)
    }

    @Test("A sync of unfinished progress keeps tracking the later local finish")
    func syncDuringPlay() {
        let fixture = Fixture()
        fixture.progress.snapshot = failedDay(lastGame: .crossword, finishLast: false)
        fixture.model.beginGame(.crossword, accountID: nil, dailyPuzzle: nil)
        fixture.progress.snapshot = failedDay(lastGame: .crossword, finishLast: false, crosswordClues: [1, 2])
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        #expect(!fixture.model.snapshot.isComplete)
        #expect(fixture.model.snapshot[.crossword].earnedPoints == 3)
        fixture.clock.now = fixture.clock.now.addingTimeInterval(1)
        fixture.progress.snapshot = failedDay(lastGame: .crossword, finishLast: true, at: fixture.clock.now)
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        #expect(fixture.haptics.played == [.wordCompleted])
    }

    @Test("Returning from a local fourth finish celebrates once and remembers acknowledgement")
    func localCompletion() {
        let fixture = Fixture()
        fixture.beginFinalGame()
        fixture.finishFinalGame()
        #expect(!fixture.model.isCelebrating)
        #expect(fixture.haptics.played.isEmpty)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        #expect(fixture.model.celebrationID == 1)
        #expect(fixture.haptics.played == [.wordCompleted])
        fixture.model.setHomeAvailable(false)
        fixture.model.setHomeAvailable(true)
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        #expect(!fixture.model.isCelebrating)
        #expect(fixture.haptics.played == [.wordCompleted])
        let recreated = fixture.makeModel()
        recreated.refresh(accountID: nil, dailyPuzzle: nil)
        recreated.setHomeAvailable(true)
        #expect(recreated.snapshot.isComplete)
        #expect(!recreated.isCelebrating)
        #expect(fixture.haptics.played.count == 1)
    }

    @Test("Incomplete and previously completed games do not celebrate")
    func noNewFinish() {
        let fixture = Fixture()
        fixture.beginFinalGame()
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(!fixture.model.isCelebrating)
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(finished: 4)
        fixture.model.beginGame(.midword, accountID: nil, dailyPuzzle: nil)
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.haptics.played.isEmpty)
    }

    @Test("A completion timestamp preceding local play cannot trigger feedback")
    func earlierCompletion() {
        let fixture = Fixture()
        fixture.beginFinalGame()
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(
            finished: 4, at: fixture.clock.now.addingTimeInterval(-60)
        )
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.snapshot.isComplete)
        #expect(fixture.haptics.played.isEmpty)
    }

    @Test("A local loss can finish the challenge")
    func terminalLoss() {
        let fixture = Fixture()
        fixture.beginFinalGame()
        var midword = MidwordProgress(date: DailyChallengeFixtures.date)
        midword.completedAt = fixture.clock.now.addingTimeInterval(1)
        let allWon = DailyChallengeFixtures.snapshot(finished: 3)
        // Build the other three completed games using the same saved types.
        var backword = BackwordProgress(date: allWon.date)
        backword.completedAt = fixture.clock.now
        var crossword = DailyChallengeFixtures.crossword()
        crossword.completedAt = fixture.clock.now
        var anagram = AnagramProgress(puzzle: DailyChallengeFixtures.anagram, now: fixture.clock.now)
        anagram.giveUp(now: fixture.clock.now)
        fixture.progress.snapshot = DailyChallengeSnapshot(
            date: allWon.date, backword: backword, crosswords: [crossword], anagram: anagram, midword: midword
        )
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        #expect(fixture.model.snapshot[.midword].state == .finished(won: false))
    }

    @Test("Initial restoration and cloud completion remain silent")
    func restoredCompletion() {
        let fixture = Fixture()
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(finished: 4)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(!fixture.model.isCelebrating)
        #expect(fixture.haptics.played.isEmpty)

        let synced = Fixture()
        synced.beginFinalGame()
        synced.progress.snapshot = DailyChallengeFixtures.snapshot(finished: 4)
        synced.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        synced.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        synced.model.setHomeAvailable(true)
        #expect(synced.model.snapshot.isComplete)
        #expect(synced.haptics.played.isEmpty)
    }

    @Test("A sync with unchanged progress preserves an observed local finish")
    func unchangedSync() {
        let fixture = Fixture()
        fixture.beginFinalGame()
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(finished: 4, at: fixture.clock.now)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.haptics.played == [.wordCompleted])
    }

    @Test("Queued local feedback survives Home refreshes while a modal closes")
    func pendingFeedback() {
        let fixture = Fixture()
        fixture.beginFinalGame()
        fixture.finishFinalGame()
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        #expect(fixture.haptics.played.isEmpty)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        #expect(fixture.haptics.played == [.wordCompleted])
    }

    #if DEBUG
    @Test("Preview works before all games are finished and leaves real progress untouched",
          arguments: [0, 1, 2, 3])
    func debugPreview(finished: Int) {
        let fixture = Fixture()
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(finished: finished)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        let saved = fixture.model.snapshot
        let acknowledged = fixture.celebrations.keys
        fixture.model.previewCelebration()
        #expect(!fixture.model.isCelebrating)

        // Match Debug sheet dismissal, Home refresh, and the return transition.
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        #expect(fixture.model.celebrationSnapshot?.games.map(\.earnedPoints) == [5, 4, 3, 0])
        #expect(fixture.model.celebrationSnapshot?.earnedPoints == 12)
        #expect(fixture.model.celebrationSnapshot?.possiblePoints == 20)
        #expect(fixture.model.celebrationSnapshot?.isComplete == true)
        #expect(fixture.model.snapshot == saved)
        #expect(fixture.progress.snapshot == saved)
        #expect(fixture.celebrations.keys == acknowledged)
        #expect(fixture.haptics.played == [.wordCompleted])

        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        #expect(fixture.model.isCelebrating)
        #expect(fixture.model.celebrationSnapshot?.earnedPoints == 12)
        fixture.model.dismissCelebration()
        #expect(fixture.model.celebrationSnapshot == nil)
        fixture.model.previewCelebration()
        #expect(fixture.model.celebrationID == 2)
        #expect(fixture.celebrations.keys == acknowledged)
    }

    @Test("A preview does not consume a later genuine completion")
    func previewThenLocalCompletion() {
        let fixture = Fixture()
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.previewCelebration()
        fixture.model.setHomeAvailable(true)
        fixture.model.dismissCelebration()
        #expect(fixture.celebrations.keys.isEmpty)
        fixture.beginFinalGame()
        fixture.finishFinalGame()
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        #expect(fixture.model.celebrationID == 2)
        #expect(fixture.model.celebrationSnapshot == fixture.model.snapshot)
        #expect(fixture.celebrations.contains(date: DailyChallengeFixtures.date, accountID: nil))
        #expect(fixture.haptics.played.count == 2)
    }

    @Test("Account changes cancel queued and visible sample previews", arguments: [false, true])
    func previewAccountChange(visible: Bool) {
        let fixture = Fixture()
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.previewCelebration()
        if visible { fixture.model.setHomeAvailable(true) }
        fixture.model.refresh(accountID: "another-player", dailyPuzzle: nil, source: .restored)
        fixture.model.setHomeAvailable(true)
        #expect(!fixture.model.isCelebrating)
        #expect(fixture.model.celebrationSnapshot == nil)
        #expect(fixture.celebrations.keys.isEmpty)
    }

    @Test("Midnight cancels queued and visible sample previews", arguments: [false, true])
    func previewMidnight(visible: Bool) {
        let fixture = Fixture()
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.previewCelebration()
        if visible { fixture.model.setHomeAvailable(true) }
        fixture.clock.now = fixture.clock.now.addingTimeInterval(86_400)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(!fixture.model.isCelebrating)
        #expect(fixture.model.celebrationSnapshot == nil)
        #expect(fixture.celebrations.keys.isEmpty)
    }

    @Test("Resetting a daily game in Debug re-arms the normal completion flow",
          arguments: DailyChallengeGame.allCases)
    func debugResetRearmsCompletion(game: DailyChallengeGame) {
        let fixture = Fixture()
        let date = DailyChallengeFixtures.date
        fixture.progress.snapshot = failedDay(lastGame: game, finishLast: true)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        #expect(fixture.celebrations.contains(date: date, accountID: nil))
        fixture.progress.snapshot = failedDay(lastGame: game, finishLast: false)
        fixture.model.resetCelebrationForDebug(date: date, accountID: nil, dailyPuzzle: nil)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        fixture.model.setHomeAvailable(true)
        #expect(!fixture.celebrations.contains(date: date, accountID: nil))
        #expect(!fixture.model.isCelebrating)
        #expect(fixture.haptics.played.isEmpty)

        fixture.model.beginGame(game, accountID: nil, dailyPuzzle: nil)
        fixture.clock.now = fixture.clock.now.addingTimeInterval(1)
        fixture.progress.snapshot = failedDay(lastGame: game, finishLast: true, at: fixture.clock.now)
        fixture.model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        #expect(fixture.haptics.played == [.wordCompleted])
        #expect(fixture.celebrations.contains(date: date, accountID: nil))
    }

    @Test("Ordinary incomplete progress and an old debug reset retain today's acknowledgement")
    func resetAcknowledgementGuards() {
        let fixture = Fixture()
        let date = DailyChallengeFixtures.date
        fixture.celebrations.acknowledge(date: date, accountID: nil)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        #expect(fixture.celebrations.contains(date: date, accountID: nil))
        fixture.model.resetCelebrationForDebug(date: "2026-11-06", accountID: nil, dailyPuzzle: nil)
        #expect(fixture.celebrations.contains(date: date, accountID: nil))
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(finished: 4)
        fixture.model.resetCelebrationForDebug(date: date, accountID: nil, dailyPuzzle: nil)
        #expect(fixture.celebrations.contains(date: date, accountID: nil))
        #expect(fixture.haptics.played.isEmpty)
    }

    @Test("Debug acknowledgement reset affects only its account and release date")
    func debugResetNamespace() throws {
        let name = "DailyChallengeResetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = DailyChallengeCelebrationStore(defaults: defaults)
        let date = DailyChallengeFixtures.date
        store.acknowledge(date: date, accountID: nil)
        store.acknowledge(date: date, accountID: "player")
        store.acknowledge(date: "2026-11-06", accountID: "player")
        store.resetAcknowledgement(date: date, accountID: "player")
        #expect(!DailyChallengeCelebrationStore(defaults: defaults).contains(date: date, accountID: "player"))
        #expect(store.contains(date: date, accountID: nil))
        #expect(store.contains(date: "2026-11-06", accountID: "player"))
    }

    @Test("Debug replay waits for the sheet to close and does not change daily acknowledgement")
    func debugReplay() {
        let fixture = Fixture()
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(finished: 4)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        let acknowledged = fixture.celebrations.keys
        fixture.model.replayCelebration()
        #expect(!fixture.model.isCelebrating)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        #expect(fixture.haptics.played == [.wordCompleted])
        #expect(fixture.celebrations.keys == acknowledged)
        fixture.model.replayCelebration()
        #expect(fixture.model.celebrationID == 2)
        #expect(fixture.celebrations.keys == acknowledged)
    }

    @Test("A reset cancels a debug replay and unfinished days cannot replay")
    func cancelledDebugReplay() {
        let fixture = Fixture()
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(finished: 4)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.replayCelebration()
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(finished: 3)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        fixture.model.replayCelebration()
        fixture.model.setHomeAvailable(true)
        #expect(!fixture.model.isCelebrating)
        #expect(fixture.haptics.played.isEmpty)
    }
    #endif

    @Test("Account switching cancels pending feedback and replaces the snapshot")
    func accountChange() {
        let fixture = Fixture()
        fixture.beginFinalGame()
        fixture.finishFinalGame()
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(finished: 0)
        fixture.model.refresh(accountID: "another-player", dailyPuzzle: nil, source: .restored)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.snapshot.finishedCount == 0)
        #expect(fixture.haptics.played.isEmpty)
    }

    @Test("Local midnight replaces today's state and discards pending feedback")
    func midnight() {
        let fixture = Fixture()
        fixture.beginFinalGame()
        fixture.finishFinalGame()
        fixture.clock.now = fixture.clock.now.addingTimeInterval(86_400)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.snapshot.date == "2026-11-08")
        #expect(fixture.model.snapshot.finishedCount == 0)
        #expect(fixture.haptics.played.isEmpty)
        #expect(fixture.progress.requestedDates.last == "2026-11-08")
    }

    @Test("A timezone change uses the new local release date")
    func timezoneChange() {
        let fixture = Fixture()
        fixture.clock.now = DailyChallengeFixtures.now.addingTimeInterval(11 * 3_600)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        fixture.clock.calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        #expect(fixture.model.snapshot.date == "2026-11-08")
        #expect(fixture.model.snapshot.finishedCount == 0)
    }

    @Test("Resetting progress cancels a queued celebration")
    func reset() {
        let fixture = Fixture()
        fixture.beginFinalGame()
        fixture.finishFinalGame()
        fixture.progress.snapshot = DailyChallengeFixtures.snapshot(finished: 0)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil, source: .restored)
        fixture.model.setHomeAvailable(true)
        #expect(!fixture.model.isCelebrating)
        #expect(fixture.haptics.played.isEmpty)
    }

    @Test("The celebration remains open until dismissed and cannot replay on returning")
    func dismissal() {
        let fixture = Fixture()
        fixture.beginFinalGame()
        fixture.finishFinalGame()
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        fixture.clock.now = fixture.clock.now.addingTimeInterval(60)
        fixture.model.refresh(accountID: nil, dailyPuzzle: nil)
        #expect(fixture.model.isCelebrating)
        fixture.model.dismissCelebration()
        #expect(!fixture.model.isCelebrating)
        fixture.model.setHomeAvailable(true)
        #expect(!fixture.model.isCelebrating)
        #expect(fixture.haptics.played.count == 1)
    }

    @Test("Acknowledgements persist separately for guest, accounts, and release dates")
    func acknowledgementNamespaces() throws {
        let name = "DailyChallengeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = DailyChallengeCelebrationStore(defaults: defaults)
        let date = DailyChallengeFixtures.date
        store.acknowledge(date: date, accountID: nil)
        #expect(DailyChallengeCelebrationStore(defaults: defaults).contains(date: date, accountID: nil))
        #expect(!store.contains(date: date, accountID: "player"))
        store.acknowledge(date: date, accountID: "player")
        #expect(store.contains(date: date, accountID: "player"))
        #expect(!store.contains(date: date, accountID: "other"))
        #expect(!store.contains(date: "2026-11-08", accountID: "player"))
    }

    private final class Clock {
        var now = DailyChallengeFixtures.now
        var calendar = DailyChallengeFixtures.calendar
    }

    private func failedDay(
        lastGame: DailyChallengeGame, finishLast: Bool,
        at: Date = DailyChallengeFixtures.now, crosswordClues: Set<Int> = []
    ) -> DailyChallengeSnapshot {
        var backword = BackwordProgress(date: DailyChallengeFixtures.date)
        backword.guesses = ["CASTLE"]
        if lastGame != .backword || finishLast { backword.completedAt = at }
        var crossword = DailyChallengeFixtures.crossword()
        crossword.completedClueIds = crosswordClues
        if lastGame != .crossword || finishLast {
            crossword.completedAt = at
            crossword.gaveUpAt = at
            crossword.gaveUpScore = 0
        }
        var anagram = AnagramProgress(puzzle: DailyChallengeFixtures.anagram, now: at)
        if lastGame != .anagram || finishLast { anagram.giveUp(now: at) }
        var midword = MidwordProgress(date: DailyChallengeFixtures.date)
        midword.guesses = ["NOTE"]
        if lastGame != .midword || finishLast { midword.completedAt = at }
        return DailyChallengeSnapshot(
            date: DailyChallengeFixtures.date, backword: backword, crosswords: [crossword],
            anagram: anagram, midword: midword
        )
    }

    private final class ProgressStore: DailyChallengeProgressLoading {
        var snapshot = DailyChallengeFixtures.snapshot(finished: 3)
        var requestedDates: [String] = []
        func load(date: String, dailyPuzzle: Puzzle?) -> DailyChallengeSnapshot {
            requestedDates.append(date)
            return snapshot.date == date ? snapshot : DailyChallengeSnapshot(date: date)
        }
    }

    private final class CelebrationStore: DailyChallengeCelebrationStoring {
        var keys: Set<String> = []
        func contains(date: String, accountID: String?) -> Bool { keys.contains("\(accountID ?? "guest"):\(date)") }
        func acknowledge(date: String, accountID: String?) { keys.insert("\(accountID ?? "guest"):\(date)") }
        #if DEBUG
        func resetAcknowledgement(date: String, accountID: String?) { keys.remove("\(accountID ?? "guest"):\(date)") }
        #endif
    }

    private final class Haptics: HapticsPlaying {
        var played: [HapticsEngine.HapticType] = []
        func play(_ type: HapticsEngine.HapticType) { played.append(type) }
    }

    @MainActor
    private final class Fixture {
        let clock = Clock()
        let progress = ProgressStore()
        let celebrations = CelebrationStore()
        let haptics = Haptics()
        lazy var model = makeModel()
        func makeModel() -> HomeDailyChallengeViewModel {
            HomeDailyChallengeViewModel(
                progressStore: progress, celebrationStore: celebrations, haptics: haptics,
                now: { [clock] in clock.now }, calendar: { [clock] in clock.calendar }
            )
        }
        func beginFinalGame() { model.beginGame(.midword, accountID: nil, dailyPuzzle: nil) }
        func finishFinalGame() {
            clock.now = clock.now.addingTimeInterval(1)
            progress.snapshot = DailyChallengeFixtures.snapshot(finished: 4, at: clock.now)
            model.returnFromGame(accountID: nil, dailyPuzzle: nil)
        }
    }
}
