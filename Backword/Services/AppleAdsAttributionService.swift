/// Configures the reporting context for Firebase's automatic Apple Ads
/// attribution. AdServices must also be linked to the application target.
/// Firebase owns token retrieval, retries and the `firebase_campaign` event;
/// emitting a second campaign or first-open event would duplicate attribution.
final class AppleAdsAttributionService {
    private let setDefaultEventParameters: ([String: String]) -> Void
    private let setUserProperty: (String, String) -> Void
    private var isConfigured = false

    init(
        setDefaultEventParameters: @escaping ([String: String]) -> Void,
        setUserProperty: @escaping (String, String) -> Void
    ) {
        self.setDefaultEventParameters = setDefaultEventParameters
        self.setUserProperty = setUserProperty
    }

    /// Call as soon as Firebase is available, before logging gameplay events.
    /// A failed Firebase setup leaves this service eligible for a later retry.
    func configureIfPossible(analyticsConfigured: Bool, environment: String) {
        guard analyticsConfigured, !isConfigured else { return }

        setDefaultEventParameters(["platform": "ios", "environment": environment])
        // A user-scoped dimension also supports acquisition/retention cohorts.
        // Refresh it on each launch because Firebase persists user properties.
        setUserProperty(environment, "app_environment")
        isConfigured = true
    }
}
