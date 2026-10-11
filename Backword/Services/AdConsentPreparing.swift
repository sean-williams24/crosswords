enum AdPrivacyOptionsRequirementStatus: Equatable {
    case unknown
    case required
    case notRequired

    var isRequired: Bool {
        self == .required
    }
}

@MainActor
protocol AdConsentPreparing {
    var privacyOptionsRequirementStatus: AdPrivacyOptionsRequirementStatus { get }
    var isPrivacyOptionsRequired: Bool { get }

    /// Refreshes the SDK's consent status without presenting any UI.
    func updateConsentInfo() async -> Bool

    /// Presents required privacy prompts after the status refresh, before requesting ads.
    func prepareForAds() async -> Bool

    func presentPrivacyOptionsForm() async
}

extension AdConsentPreparing {
    var isPrivacyOptionsRequired: Bool {
        privacyOptionsRequirementStatus.isRequired
    }
}
