import Foundation
import Testing
@testable import Backword

@Suite("Interstitial presentation gate")
struct InterstitialPresentationGateTests {
    @Test("First eligible presentation consumes the daily slot")
    func firstPresentationConsumesDailySlot() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let gate = makeGate(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_768_996_800) // 2026-01-20 12:00:00 UTC

        #expect(gate.shouldPresent(type: .dailyPuzzleOpen, now: now))

        gate.markPresented(type: .dailyPuzzleOpen, now: now)

        #expect(!gate.shouldPresent(type: .dailyPuzzleOpen, now: now))
    }

    @Test("Same-day repeat skips ad")
    func sameDayRepeatSkipsAd() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let gate = makeGate(defaults: defaults)
        let firstTap = Date(timeIntervalSince1970: 1_768_996_800) // 2026-01-20 12:00:00 UTC
        let laterSameDay = Date(timeIntervalSince1970: 1_769_014_800) // 2026-01-20 17:00:00 UTC

        gate.markPresented(type: .backwordOpen, now: firstTap)

        #expect(!gate.shouldPresent(type: .backwordOpen, now: laterSameDay))
    }

    @Test("No loaded ad or presenter does not consume the daily slot")
    func unavailableAdDoesNotConsumeDailySlot() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let gate = makeGate(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_768_996_800) // 2026-01-20 12:00:00 UTC

        #expect(gate.shouldPresent(type: .dailyPuzzleOpen, now: now))
        // AdService only calls markPresented after it has both a loaded ad and a presenter.
        #expect(gate.shouldPresent(type: .dailyPuzzleOpen, now: now))
    }

    @Test("Failed presentation clears slot and allows future attempts")
    func failedPresentationClearsSlot() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let gate = makeGate(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_768_996_800) // 2026-01-20 12:00:00 UTC

        gate.markPresented(type: .dailyPuzzleOpen, now: now)
        #expect(!gate.shouldPresent(type: .dailyPuzzleOpen, now: now))

        gate.clearPresented(type: .dailyPuzzleOpen)

        #expect(gate.shouldPresent(type: .dailyPuzzleOpen, now: now))
    }

    private var defaultsSuiteName: String {
        "InterstitialPresentationGateTests"
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return defaults
    }

    private func makeGate(defaults: UserDefaults) -> InterstitialPresentationGate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return InterstitialPresentationGate(userDefaults: defaults, calendar: calendar)
    }
}
