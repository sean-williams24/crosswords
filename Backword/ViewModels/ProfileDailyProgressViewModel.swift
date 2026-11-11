import Foundation
import Combine

@MainActor
final class ProfileDailyProgressViewModel: ObservableObject {
    @Published private(set) var snapshot: DailyChallengeSnapshot
    private let store: DailyChallengeProgressLoading
    private let now: () -> Date

    init(store: DailyChallengeProgressLoading = DailyChallengeProgressStore(), now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
        snapshot = DailyChallengeSnapshot(date: ContentReleaseCalendar(now: now()).dailyDateString)
    }

    func refresh() {
        let current = now()
        let date = ContentReleaseCalendar(now: current).dailyDateString
        snapshot = store.load(date: date, dailyPuzzle: nil, now: current)
    }
}
