import Foundation
import Testing
@testable import Backword

@MainActor
@Suite("Home daily challenge lifecycle")
struct HomeDailyChallengeViewModelTests {
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

    @Test("The completion overlay dismisses without another haptic")
    func dismissal() async throws {
        let fixture = Fixture(duration: .milliseconds(1))
        fixture.beginFinalGame()
        fixture.finishFinalGame()
        fixture.model.setHomeAvailable(true)
        #expect(fixture.model.isCelebrating)
        try await Task.sleep(for: .milliseconds(30))
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
        let duration: Duration
        lazy var model = makeModel()
        init(duration: Duration = .seconds(3.5)) { self.duration = duration }
        func makeModel() -> HomeDailyChallengeViewModel {
            HomeDailyChallengeViewModel(
                progressStore: progress, celebrationStore: celebrations, haptics: haptics,
                now: { [clock] in clock.now }, calendar: { [clock] in clock.calendar },
                celebrationDuration: duration
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
