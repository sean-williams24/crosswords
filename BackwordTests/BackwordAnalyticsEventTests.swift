import Foundation
import Testing
@testable import Backword

@Suite("Backword analytics events")
struct BackwordAnalyticsEventTests {
    @Test("Ad lifecycle event includes placement, result, and environment")
    func adLifecycleEventIncludesExpectedParameters() {
        let event = BackwordAnalyticsEvent.adLifecycle(
            action: .presentationRequested,
            format: .interstitial,
            placement: .dailyPuzzleOpen,
            attemptID: "attempt-123",
            result: "ready",
            presentedAt: Date(timeIntervalSince1970: 1_800),
            secondsSincePresent: 12.34,
            environment: "test"
        )

        #expect(event.name == "bw_ad_lifecycle")
        #expect(event.parameters["action"] == "presentation_requested")
        #expect(event.parameters["ad_format"] == "interstitial")
        #expect(event.parameters["placement"] == "daily_puzzle_open")
        #expect(event.parameters["ad_attempt_id"] == "attempt-123")
        #expect(event.parameters["result"] == "ready")
        #expect(event.parameters["presented_at"] == "1970-01-01T00:30:00Z")
        #expect(event.parameters["seconds_since_present"] == "12.3")
        #expect(event.parameters["environment"] == "test")
    }

    @Test("Ad lifecycle error event stores sanitized error details")
    func adLifecycleErrorEventStoresSanitizedDetails() {
        let error = NSError(domain: "com.backword.ads", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "Do not send this message to analytics"
        ])

        let event = BackwordAnalyticsEvent.adLifecycle(
            action: .failedToPresent,
            format: .rewarded,
            error: error,
            environment: "test"
        )

        #expect(event.parameters["error_domain"] == "com.backword.ads")
        #expect(event.parameters["error_code"] == "42")
        #expect(event.parameters["error_description"] == nil)
    }
}
