import Combine
import Foundation

@MainActor
final class HomeDailyChallengeViewModel: ObservableObject {
    enum RefreshSource { case local, restored }

    private struct Context: Equatable {
        let date: String
        let accountID: String?
    }

    private struct Attempt {
        let context: Context
        let game: DailyChallengeGame
        let startedAt: Date
        let wasFinished: Bool
    }

    @Published private(set) var snapshot: DailyChallengeSnapshot
    @Published private(set) var isCelebrating = false
    @Published private(set) var celebrationSnapshot: DailyChallengeSnapshot?
    @Published private(set) var celebrationID = 0
    private let progressStore: DailyChallengeProgressLoading
    private let celebrationStore: DailyChallengeCelebrationStoring
    private let haptics: HapticsPlaying
    private let now: () -> Date
    private let calendar: () -> Calendar
    private var context: Context?
    private var attempt: Attempt?
    private var pendingCelebration: Context?
    #if DEBUG
    private var pendingReplay: Context?
    private var pendingPreview: Context?
    #endif
    private var isHomeAvailable = false
    private var isPreviewing = false

    init(
        progressStore: DailyChallengeProgressLoading = DailyChallengeProgressStore(),
        celebrationStore: DailyChallengeCelebrationStoring = DailyChallengeCelebrationStore(),
        haptics: HapticsPlaying = HapticsEngine(),
        now: @escaping () -> Date = Date.init,
        calendar: @escaping () -> Calendar = { .current }
    ) {
        self.progressStore = progressStore
        self.celebrationStore = celebrationStore
        self.haptics = haptics
        self.now = now
        self.calendar = calendar
        snapshot = DailyChallengeSnapshot(date: ContentReleaseCalendar(now: now(), calendar: calendar()).dailyDateString)
    }

    func refresh(accountID: String?, dailyPuzzle: Puzzle?, source: RefreshSource = .local) {
        let next = Context(
            date: ContentReleaseCalendar(now: now(), calendar: calendar()).dailyDateString,
            accountID: accountID
        )
        let loaded = progressStore.load(date: next.date, dailyPuzzle: dailyPuzzle)
        if context != next {
            isPreviewing = false
            #if DEBUG
            pendingPreview = nil
            #endif
        }
        // A sync that leaves daily progress unchanged must not consume a local
        // finish already observed before the sync (for example after an ad).
        if context != next || (source == .restored && loaded != snapshot) {
            // Sync can update an unfinished attempt (for example crossword
            // points) while gameplay is open. Keep tracking its later local
            // finish; an imported terminal result still remains silent.
            let preservesAttempt = context == next && attempt.map { !loaded[$0.game].isFinished } == true
            if !preservesAttempt { attempt = nil }
            pendingCelebration = nil
            #if DEBUG
            pendingReplay = nil
            #endif
            if !isPreviewing { dismissCelebration() }
        }
        context = next
        snapshot = loaded
        if !snapshot.isComplete {
            pendingCelebration = nil
            #if DEBUG
            pendingReplay = nil
            #endif
            if !isPreviewing { dismissCelebration() }
        } else if attempt == nil && pendingCelebration == nil,
                  !celebrationStore.contains(date: next.date, accountID: next.accountID) {
            // Already-complete results are restored silently, including on a new device.
            celebrationStore.acknowledge(date: next.date, accountID: next.accountID)
        }
    }

    func beginGame(_ game: DailyChallengeGame, accountID: String?, dailyPuzzle: Puzzle?) {
        refresh(accountID: accountID, dailyPuzzle: dailyPuzzle)
        guard let context else { return }
        attempt = Attempt(context: context, game: game, startedAt: now(), wasFinished: snapshot[game].isFinished)
        setHomeAvailable(false)
    }

    func returnFromGame(accountID: String?, dailyPuzzle: Puzzle?) {
        let previousAttempt = attempt
        refresh(accountID: accountID, dailyPuzzle: dailyPuzzle)
        attempt = nil
        guard let context, let previousAttempt,
              previousAttempt.context == context,
              !previousAttempt.wasFinished, snapshot.isComplete,
              let completedAt = snapshot[previousAttempt.game].completedAt,
              completedAt >= previousAttempt.startedAt,
              !celebrationStore.contains(date: context.date, accountID: context.accountID)
        else { return }
        pendingCelebration = context
        presentIfPossible()
    }

    func setHomeAvailable(_ available: Bool) {
        isHomeAvailable = available
        if available {
            presentIfPossible()
        } else {
            dismissCelebration()
        }
    }

    func dismissCelebration() {
        isCelebrating = false
        celebrationSnapshot = nil
        isPreviewing = false
    }

    #if DEBUG
    /// Re-arm the real completion flow after a daily game's debug reset.
    /// Ordinary refreshes and cloud changes retain the once-per-day policy.
    func resetCelebrationForDebug(date: String, accountID: String?, dailyPuzzle: Puzzle?) {
        guard date == ContentReleaseCalendar(now: now(), calendar: calendar()).dailyDateString else { return }
        refresh(accountID: accountID, dailyPuzzle: dailyPuzzle, source: .restored)
        guard !snapshot.isComplete else { return }
        attempt = nil
        pendingCelebration = nil
        pendingReplay = nil
        pendingPreview = nil
        dismissCelebration()
        celebrationStore.resetAcknowledgement(date: date, accountID: accountID)
    }

    /// Preview the real feedback after the Debug sheet closes, without changing
    /// saved games or the once-per-day acknowledgement.
    func replayCelebration() {
        guard snapshot.isComplete, let context else { return }
        pendingReplay = context
        presentIfPossible()
    }

    /// Exercise the real presentation with sample scores, even on an unplayed day.
    func previewCelebration() {
        guard let context else { return }
        pendingPreview = context
        presentIfPossible()
    }
    #endif

    private func presentIfPossible() {
        #if DEBUG
        if isHomeAvailable, let preview = pendingPreview, preview == context,
           preview.date == ContentReleaseCalendar(now: now(), calendar: calendar()).dailyDateString {
            pendingPreview = nil
            startCelebration(snapshot: .celebrationPreview(date: preview.date), isPreview: true)
            return
        }
        if isHomeAvailable, let replay = pendingReplay, replay == context,
           replay.date == ContentReleaseCalendar(now: now(), calendar: calendar()).dailyDateString,
           snapshot.isComplete {
            pendingReplay = nil
            startCelebration()
            return
        }
        #endif
        guard isHomeAvailable, let pending = pendingCelebration, pending == context,
              pending.date == ContentReleaseCalendar(now: now(), calendar: calendar()).dailyDateString,
              snapshot.isComplete else { return }
        pendingCelebration = nil
        guard !celebrationStore.contains(date: pending.date, accountID: pending.accountID) else { return }
        celebrationStore.acknowledge(date: pending.date, accountID: pending.accountID)
        startCelebration()
    }

    private func startCelebration(snapshot presentation: DailyChallengeSnapshot? = nil, isPreview: Bool = false) {
        dismissCelebration()
        celebrationSnapshot = presentation ?? snapshot
        isPreviewing = isPreview
        celebrationID += 1
        isCelebrating = true
        haptics.play(.wordCompleted)
    }
}
