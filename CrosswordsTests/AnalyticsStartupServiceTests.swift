import Foundation
import Testing
@testable import Backword

@Suite("Analytics privacy at startup")
struct AnalyticsStartupServiceTests {
    @Test("New SDK setup restricts advertising before measurement becomes available")
    func newSDKSetup() {
        let recorder = AnalyticsStartupRecorder()
        let service = recorder.makeService()

        recorder.beforeMeasurement = { [unowned service] in
            #expect(!service.isConfigured)
        }

        #expect(service.configureIfPossible())
        #expect(service.isConfigured)
        #expect(recorder.events == ["configure-sdk", "restrict-advertising", "measurement"])
    }

    @Test("An already configured SDK still receives advertising restrictions")
    func existingSDKSetup() {
        let recorder = AnalyticsStartupRecorder()
        recorder.sdkConfigured = true
        let service = recorder.makeService()

        #expect(service.configureIfPossible())
        #expect(recorder.events == ["restrict-advertising", "measurement"])
    }

    @Test("Unavailable configuration does not start SDK or measurement")
    func missingConfiguration() {
        let recorder = AnalyticsStartupRecorder()
        recorder.hasConfiguration = false
        let service = recorder.makeService()

        #expect(!service.configureIfPossible())
        #expect(!service.isConfigured)
        #expect(recorder.events.isEmpty)

        recorder.hasConfiguration = true
        #expect(service.configureIfPossible())
        #expect(recorder.events == ["configure-sdk", "restrict-advertising", "measurement"])
    }

    @Test("Failed SDK setup remains retryable without writing measurement context")
    func failedSDKSetup() {
        let recorder = AnalyticsStartupRecorder()
        recorder.sdkSetupSucceeds = false
        let service = recorder.makeService()

        #expect(!service.configureIfPossible())
        #expect(!service.isConfigured)
        #expect(recorder.events == ["configure-sdk"])

        recorder.sdkSetupSucceeds = true
        #expect(service.configureIfPossible())
        #expect(recorder.events == ["configure-sdk", "configure-sdk", "restrict-advertising", "measurement"])
    }

    @Test("Repeated setup does not revoke consent again or clear measurement context")
    func repeatedSetup() {
        let recorder = AnalyticsStartupRecorder()
        let service = recorder.makeService()

        #expect(service.configureIfPossible())
        #expect(service.configureIfPossible())
        #expect(recorder.events == ["configure-sdk", "restrict-advertising", "measurement"])
    }

    @Test("Each launch restores reporting properties after revoking advertising use")
    func restoresAppleAdsContextAfterRestriction() {
        let recorder = AnalyticsStartupRecorder()
        recorder.sdkConfigured = true
        var userProperties = ["app_environment": "testflight"]
        var defaults: [String: String] = [:]
        recorder.onRestriction = { userProperties.removeAll() }

        func makeLaunch() -> AnalyticsStartupService {
            let attribution = AppleAdsAttributionService(
                setDefaultEventParameters: { defaults = $0 },
                setUserProperty: { userProperties[$1] = $0 }
            )
            return recorder.makeService {
                attribution.configureIfPossible(analyticsConfigured: true, environment: "appstore")
            }
        }

        #expect(makeLaunch().configureIfPossible())
        #expect(userProperties == ["app_environment": "appstore"])
        #expect(defaults == ["platform": "ios", "environment": "appstore"])
        #expect(makeLaunch().configureIfPossible())
        #expect(userProperties == ["app_environment": "appstore"])
        #expect(recorder.events == ["restrict-advertising", "measurement", "restrict-advertising", "measurement"])
    }
}

#if os(iOS)
@Suite("Firebase advertising defaults in the iOS app")
struct AnalyticsAdvertisingDefaultsTests {
    @Test("Automatic analytics events default to denied advertising permissions")
    func advertisingDefaultsAreDenied() throws {
        let info = try #require(Bundle.main.infoDictionary)
        for key in [
            "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE",
            "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA",
            "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS"
        ] {
            #expect(info[key] as? Bool == false)
        }
        // This policy must not force analytics consent or enable collection.
        #expect(info["GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE"] == nil)
        #expect(info["FIREBASE_ANALYTICS_COLLECTION_ENABLED"] == nil)
    }
}
#endif

private final class AnalyticsStartupRecorder {
    var hasConfiguration = true
    var sdkConfigured = false
    var sdkSetupSucceeds = true
    var events: [String] = []
    var beforeMeasurement: (() -> Void)?
    var onRestriction: (() -> Void)?

    func makeService(measurement: @escaping () -> Void = {}) -> AnalyticsStartupService {
        AnalyticsStartupService(
            hasConfigurationFile: { self.hasConfiguration },
            isSDKConfigured: { self.sdkConfigured },
            configureSDK: {
                self.events.append("configure-sdk")
                self.sdkConfigured = self.sdkSetupSucceeds
            },
            restrictAdvertisingUse: {
                self.events.append("restrict-advertising")
                self.onRestriction?()
            },
            configureMeasurement: {
                self.beforeMeasurement?()
                self.events.append("measurement")
                measurement()
            }
        )
    }
}
