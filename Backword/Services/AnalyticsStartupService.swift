/// Applies analytics advertising restrictions before any app-owned measurement.
/// SDK defaults in Info.plist also cover automatic events during SDK startup.
final class AnalyticsStartupService {
    private let hasConfigurationFile: () -> Bool
    private let isSDKConfigured: () -> Bool
    private let configureSDK: () -> Void
    private let restrictAdvertisingUse: () -> Void
    private let configureMeasurement: () -> Void
    private let setAnalyticsConsent: (Bool) -> Void
    private let setCollectionEnabled: (Bool) -> Void
    private let resetAnalyticsData: () -> Void
    private let onReady: () -> Void
    private var hasConsent = false

    var canLogEvents: Bool { hasConsent && isConfigured }

    private(set) var isConfigured = false

    init(
        hasConfigurationFile: @escaping () -> Bool,
        isSDKConfigured: @escaping () -> Bool,
        configureSDK: @escaping () -> Void,
        restrictAdvertisingUse: @escaping () -> Void,
        configureMeasurement: @escaping () -> Void,
        setAnalyticsConsent: @escaping (Bool) -> Void,
        setCollectionEnabled: @escaping (Bool) -> Void,
        resetAnalyticsData: @escaping () -> Void,
        onReady: @escaping () -> Void = {}
    ) {
        self.hasConfigurationFile = hasConfigurationFile
        self.isSDKConfigured = isSDKConfigured
        self.configureSDK = configureSDK
        self.restrictAdvertisingUse = restrictAdvertisingUse
        self.configureMeasurement = configureMeasurement
        self.setAnalyticsConsent = setAnalyticsConsent
        self.setCollectionEnabled = setCollectionEnabled
        self.resetAnalyticsData = resetAnalyticsData
        self.onReady = onReady
    }

    func updateConsent(isGranted: Bool) {
        let wasGranted = hasConsent
        hasConsent = isGranted
        if isGranted {
            configureIfPossible()
        } else {
            isConfigured = false
            // Do not initialise Firebase merely to record a refusal.
            guard isSDKConfigured() else { return }
            setCollectionEnabled(false)
            if wasGranted { resetAnalyticsData() }
            setAnalyticsConsent(false)
            restrictAdvertisingUse()
        }
    }

    /// Register the SDK during app launch, before foreground lifecycle events.
    /// SDK configuration alone must never enable analytics collection.
    @discardableResult
    func prepareForLaunch() -> Bool {
        guard !isSDKConfigured() else { return true }
        guard hasConfigurationFile() else { return false }

        // The runtime flag overrides a collection preference saved by an older
        // release. Apply it before configuring the SDK, including on upgrades.
        setCollectionEnabled(false)
        configureSDK()
        return isSDKConfigured()
    }

    @discardableResult
    func configureIfPossible() -> Bool {
        guard hasConsent else { return false }
        guard !isConfigured else { return true }
        guard prepareForLaunch() else { return false }

        // Revoking ad storage can clear user properties. Restore measurement
        // context after consent changes, then enable automatic collection last.
        restrictAdvertisingUse()
        setAnalyticsConsent(true)
        configureMeasurement()
        setCollectionEnabled(true)
        isConfigured = true
        onReady()
        return true
    }
}
