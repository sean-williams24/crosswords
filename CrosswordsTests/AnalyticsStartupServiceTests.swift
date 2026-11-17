import Foundation
import Testing
@testable import Backword

@Suite("Analytics privacy at startup")
struct AnalyticsStartupServiceTests {
    @MainActor
    @Test("First-install banner acceptance enables measurement regardless of SwiftUI launch ordering",
          arguments: [false, true])
    func bannerAcceptanceAfterFreshLaunch(modelBeforeLaunch: Bool) {
        let suiteName = "AnalyticsLaunchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let recorder = AnalyticsStartupRecorder()
        let service = recorder.makeService()
        func makeModel() -> AnalyticsConsentViewModel {
            AnalyticsConsentViewModel(defaults: defaults, applyConsent: {
                service.updateConsent(isGranted: $0)
            })
        }

        let model: AnalyticsConsentViewModel
        if modelBeforeLaunch {
            model = makeModel()
            #expect(service.prepareForLaunch())
        } else {
            #expect(service.prepareForLaunch())
            model = makeModel()
        }
        #expect(model.shouldShowPrompt)
        #expect(!service.canLogEvents)
        #expect(!recorder.events.contains("collection-true"))
        #expect(!recorder.events.contains("measurement"))

        model.setEnabled(true)

        #expect(!model.shouldShowPrompt)
        #expect(AnalyticsConsent.savedChoice(in: defaults) == .accepted)
        #expect(service.canLogEvents)
        #expect(recorder.events.last == "collection-true")
        #expect(recorder.events.filter { $0 == "configure-sdk" }.count == 1)
    }

    @Test("A fresh launch prepares the SDK with collection off, then accepts without reinitialising")
    func freshLaunchThenAcceptance() {
        let recorder = AnalyticsStartupRecorder()
        let service = recorder.makeService()
        #expect(service.prepareForLaunch())
        #expect(recorder.events == ["collection-false", "configure-sdk"])
        #expect(!service.canLogEvents)
        service.updateConsent(isGranted: false)
        #expect(!service.canLogEvents)
        #expect(!service.isConfigured)
        recorder.events.removeAll()
        service.updateConsent(isGranted: true)
        #expect(recorder.events == ["restrict-advertising", "storage-true", "measurement", "collection-true"])
        #expect(service.canLogEvents)
    }

    @Test("Repeated launch preparation never enables collection or reconfigures the SDK")
    func repeatedLaunchPreparation() {
        let recorder = AnalyticsStartupRecorder()
        let service = recorder.makeService()
        #expect(service.prepareForLaunch())
        #expect(service.prepareForLaunch())
        service.updateConsent(isGranted: false)
        #expect(!service.canLogEvents)
        #expect(!recorder.events.contains("collection-true"))
        #expect(!recorder.events.contains("measurement"))
        #expect(recorder.events.filter { $0 == "configure-sdk" }.count == 1)
    }

    @Test("Missing launch configuration remains retryable without enabling measurement")
    func missingLaunchConfiguration() {
        let recorder = AnalyticsStartupRecorder()
        recorder.hasConfiguration = false
        let service = recorder.makeService()
        #expect(!service.prepareForLaunch())
        #expect(recorder.events.isEmpty)
        recorder.hasConfiguration = true
        #expect(service.prepareForLaunch())
        #expect(recorder.events == ["collection-false", "configure-sdk"])
        #expect(!service.canLogEvents)
    }

    @Test("Readiness diagnostics run only after consent and successful collection setup")
    func readinessDiagnostics() {
        let recorder = AnalyticsStartupRecorder()
        var readyCount = 0
        let service = recorder.makeService(onReady: {
            #expect(recorder.events.last == "collection-true")
            readyCount += 1
        })
        service.updateConsent(isGranted: false)
        #expect(readyCount == 0)
        recorder.hasConfiguration = false
        service.updateConsent(isGranted: true)
        #expect(readyCount == 0)
        recorder.hasConfiguration = true
        recorder.sdkSetupSucceeds = false
        #expect(!service.configureIfPossible())
        #expect(readyCount == 0)
        recorder.sdkSetupSucceeds = true
        #expect(service.configureIfPossible())
        #expect(readyCount == 1)
        service.updateConsent(isGranted: true)
        #expect(readyCount == 1)
        service.updateConsent(isGranted: false)
        #expect(readyCount == 1)
        service.updateConsent(isGranted: true)
        #expect(readyCount == 2)
    }

    @Test("Consent changes alone do not initialise the SDK before app launch")
    func noConsent() {
        let recorder = AnalyticsStartupRecorder()
        let service = recorder.makeService()
        #expect(!service.configureIfPossible())
        service.updateConsent(isGranted: false)
        #expect(recorder.events.isEmpty)
        #expect(!service.canLogEvents)
    }

    @Test("Acceptance grants storage before context and enables collection last")
    func acceptance() {
        let recorder = AnalyticsStartupRecorder()
        let service = recorder.makeService()
        service.updateConsent(isGranted: true)
        #expect(service.canLogEvents)
        #expect(recorder.events == ["collection-false", "configure-sdk", "restrict-advertising", "storage-true", "measurement", "collection-true"])
        service.updateConsent(isGranted: true)
        #expect(service.configureIfPossible())
        #expect(recorder.events.count == 6)
    }

    @Test("Existing SDK receives consent restrictions before measurement")
    func existingSDK() {
        let recorder = AnalyticsStartupRecorder()
        recorder.sdkConfigured = true
        let service = recorder.makeService()
        service.updateConsent(isGranted: true)
        #expect(recorder.events == ["restrict-advertising", "storage-true", "measurement", "collection-true"])
    }

    @Test("Declining disables an existing SDK without setting up measurement")
    func declinedExistingSDK() {
        let recorder = AnalyticsStartupRecorder()
        recorder.sdkConfigured = true
        let service = recorder.makeService()
        service.updateConsent(isGranted: false)
        #expect(!service.canLogEvents)
        #expect(recorder.events == ["collection-false", "storage-false", "restrict-advertising"])
    }

    @Test("Withdrawal stops events, clears analytics data and allows a fresh opt-in")
    func withdrawAndReaccept() {
        let recorder = AnalyticsStartupRecorder()
        let service = recorder.makeService()
        service.updateConsent(isGranted: true)
        recorder.events.removeAll()
        recorder.onReset = { #expect(!service.canLogEvents) }
        service.updateConsent(isGranted: false)
        #expect(!service.isConfigured)
        #expect(!service.canLogEvents)
        #expect(!service.configureIfPossible())
        #expect(recorder.events == ["collection-false", "reset", "storage-false", "restrict-advertising"])
        recorder.events.removeAll()
        service.updateConsent(isGranted: true)
        #expect(service.canLogEvents)
        #expect(recorder.events == ["restrict-advertising", "storage-true", "measurement", "collection-true"])
    }

    @Test("Missing configuration can retry after consent without collecting early")
    func missingConfiguration() {
        let recorder = AnalyticsStartupRecorder()
        recorder.hasConfiguration = false
        let service = recorder.makeService()
        service.updateConsent(isGranted: true)
        #expect(!service.canLogEvents)
        #expect(recorder.events.isEmpty)
        recorder.hasConfiguration = true
        #expect(service.configureIfPossible())
        #expect(service.canLogEvents)
    }

    @Test("Failed SDK setup remains retryable without enabling collection")
    func failedSDKSetup() {
        let recorder = AnalyticsStartupRecorder()
        recorder.sdkSetupSucceeds = false
        let service = recorder.makeService()
        service.updateConsent(isGranted: true)
        #expect(!service.canLogEvents)
        #expect(recorder.events == ["collection-false", "configure-sdk"])
        recorder.sdkSetupSucceeds = true
        #expect(service.configureIfPossible())
        #expect(recorder.events == ["collection-false", "configure-sdk", "collection-false", "configure-sdk", "restrict-advertising", "storage-true", "measurement", "collection-true"])
    }

    @Test("Revoked consent prevents a previously failed startup from retrying")
    func revokedFailedStartup() {
        let recorder = AnalyticsStartupRecorder()
        recorder.sdkSetupSucceeds = false
        let service = recorder.makeService()
        service.updateConsent(isGranted: true)
        service.updateConsent(isGranted: false)
        recorder.sdkSetupSucceeds = true
        #expect(!service.configureIfPossible())
        #expect(recorder.events == ["collection-false", "configure-sdk"])
    }

    @Test("Reacceptance restores Apple Ads context after analytics reset")
    func restoresAttributionContext() {
        var properties: [String: String] = [:]
        let attribution = AppleAdsAttributionService(
            setDefaultEventParameters: { _ in },
            setUserProperty: { properties[$1] = $0 }
        )
        let recorder = AnalyticsStartupRecorder()
        recorder.onReset = { properties.removeAll(); attribution.reset() }
        let service = recorder.makeService(measurement: {
            attribution.configureIfPossible(analyticsConfigured: true, environment: "appstore")
        })
        service.updateConsent(isGranted: true)
        #expect(properties == ["app_environment": "appstore"])
        service.updateConsent(isGranted: false)
        #expect(properties.isEmpty)
        service.updateConsent(isGranted: true)
        #expect(properties == ["app_environment": "appstore"])
    }
}

#if os(iOS)
@Suite("Firebase privacy defaults in the iOS app")
struct AnalyticsAdvertisingDefaultsTests {
    @Test("Automatic analytics and advertising permissions default to disabled")
    func privacyDefaultsAreDenied() throws {
        let info = try #require(Bundle.main.infoDictionary)
        for key in [
            "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE",
            "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA",
            "GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS",
            "GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE",
            "FIREBASE_ANALYTICS_COLLECTION_ENABLED"
        ] {
            #expect(info[key] as? Bool == false)
        }
    }
}
#endif

private final class AnalyticsStartupRecorder {
    var hasConfiguration = true
    var sdkConfigured = false
    var sdkSetupSucceeds = true
    var events: [String] = []
    var onReset: (() -> Void)?

    func makeService(onReady: @escaping () -> Void = {}, measurement: @escaping () -> Void = {}) -> AnalyticsStartupService {
        AnalyticsStartupService(
            hasConfigurationFile: { self.hasConfiguration },
            isSDKConfigured: { self.sdkConfigured },
            configureSDK: {
                self.events.append("configure-sdk")
                self.sdkConfigured = self.sdkSetupSucceeds
            },
            restrictAdvertisingUse: { self.events.append("restrict-advertising") },
            configureMeasurement: {
                self.events.append("measurement")
                measurement()
            },
            setAnalyticsConsent: { self.events.append("storage-\($0)") },
            setCollectionEnabled: { self.events.append("collection-\($0)") },
            resetAnalyticsData: {
                self.events.append("reset")
                self.onReset?()
            },
            onReady: onReady
        )
    }
}
