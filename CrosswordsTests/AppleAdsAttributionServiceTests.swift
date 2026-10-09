import Testing
@testable import Backword

@Suite("Apple Ads measurement configuration")
struct AppleAdsAttributionServiceTests {
    @Test("Missing Firebase configuration does not write measurement context")
    func unavailableAnalyticsDoesNotWriteContext() {
        let recorder = MeasurementRecorder()
        let service = recorder.makeService()

        service.configureIfPossible(analyticsConfigured: false, environment: "appstore")

        #expect(recorder.defaultParameters.isEmpty)
        #expect(recorder.userProperties.isEmpty)
    }

    @Test("A failed setup can be retried once Firebase becomes available")
    func retryAfterFirebaseConfiguration() {
        let recorder = MeasurementRecorder()
        let service = recorder.makeService()

        service.configureIfPossible(analyticsConfigured: false, environment: "appstore")
        service.configureIfPossible(analyticsConfigured: true, environment: "appstore")
        service.configureIfPossible(analyticsConfigured: true, environment: "appstore")

        #expect(recorder.defaultParameters == [["platform": "ios", "environment": "appstore"]])
        #expect(recorder.userProperties == [["app_environment": "appstore"]])
    }

    @Test("Test and production launches label automatic events and user cohorts", arguments: ["debug", "testflight", "appstore"])
    func separatesEnvironmentCohorts(environment: String) {
        let recorder = MeasurementRecorder()
        let service = recorder.makeService()

        service.configureIfPossible(analyticsConfigured: true, environment: environment)

        #expect(recorder.defaultParameters == [["platform": "ios", "environment": environment]])
        #expect(recorder.userProperties == [["app_environment": environment]])
    }

    @Test("A new launch replaces a persisted TestFlight cohort with production")
    func refreshesPersistedEnvironmentOnNewLaunch() {
        let recorder = MeasurementRecorder()
        let testFlightLaunch = recorder.makeService()
        testFlightLaunch.configureIfPossible(analyticsConfigured: true, environment: "testflight")

        let appStoreLaunch = recorder.makeService()
        appStoreLaunch.configureIfPossible(analyticsConfigured: true, environment: "appstore")

        #expect(recorder.defaultParameters.last?["environment"] == "appstore")
        #expect(recorder.userProperties.last?["app_environment"] == "appstore")
        #expect(recorder.userProperties.count == 2)
    }
}

private final class MeasurementRecorder {
    var defaultParameters: [[String: String]] = []
    var userProperties: [[String: String]] = []

    func makeService() -> AppleAdsAttributionService {
        AppleAdsAttributionService(
            setDefaultEventParameters: { self.defaultParameters.append($0) },
            setUserProperty: { self.userProperties.append([$1: $0]) }
        )
    }
}
