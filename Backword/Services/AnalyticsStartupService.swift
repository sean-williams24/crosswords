/// Applies analytics advertising restrictions before any app-owned measurement.
/// SDK defaults in Info.plist also cover automatic events during SDK startup.
final class AnalyticsStartupService {
    private let hasConfigurationFile: () -> Bool
    private let isSDKConfigured: () -> Bool
    private let configureSDK: () -> Void
    private let restrictAdvertisingUse: () -> Void
    private let configureMeasurement: () -> Void

    private(set) var isConfigured = false

    init(
        hasConfigurationFile: @escaping () -> Bool,
        isSDKConfigured: @escaping () -> Bool,
        configureSDK: @escaping () -> Void,
        restrictAdvertisingUse: @escaping () -> Void,
        configureMeasurement: @escaping () -> Void
    ) {
        self.hasConfigurationFile = hasConfigurationFile
        self.isSDKConfigured = isSDKConfigured
        self.configureSDK = configureSDK
        self.restrictAdvertisingUse = restrictAdvertisingUse
        self.configureMeasurement = configureMeasurement
    }

    @discardableResult
    func configureIfPossible() -> Bool {
        guard !isConfigured else { return true }
        guard hasConfigurationFile() else { return false }

        if !isSDKConfigured() {
            configureSDK()
        }
        guard isSDKConfigured() else { return false }

        // Revoking ad storage can clear user properties. Restore measurement
        // context afterward, and leave analytics collection/consent untouched.
        restrictAdvertisingUse()
        configureMeasurement()
        isConfigured = true
        return true
    }
}
