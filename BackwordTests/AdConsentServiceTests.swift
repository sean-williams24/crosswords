import Foundation
import Testing
@testable import Backword

@Suite("Ad consent startup")
struct AdConsentServiceTests {
    @Test("Ad startup stops when consent preparation cannot request ads")
    @MainActor
    func adStartupStopsWhenConsentPreparationFails() async {
        let consentService = FakeAdConsentService(
            canRequestAds: false,
            privacyOptionsRequirementStatus: .required
        )
        let adService = AdService(adConsentService: consentService)

        let canRequestAds = await adService.prepareAdsIfNeeded()

        #expect(!canRequestAds)
        #expect(consentService.prepareCallCount == 1)
        #expect(adService.isPrivacyOptionsRequired)
        #expect(adService.adStartupDidComplete)
        #expect(!adService.isPresentingFullScreenAd)
    }

    @Test("Interstitial gate continues when consent startup is not ready")
    @MainActor
    func interstitialGateContinuesWhenConsentStartupIsNotReady() {
        let consentService = FakeAdConsentService(canRequestAds: false)
        let adService = AdService(adConsentService: consentService)
        var didContinue = false

        adService.showInterstitialOnce(for: .dailyPuzzleOpen) {
            didContinue = true
        }

        #expect(didContinue)
    }

    @Test("Privacy choices state follows consent service requirement")
    @MainActor
    func privacyChoicesStateFollowsConsentServiceRequirement() {
        let consentService = FakeAdConsentService(
            canRequestAds: false,
            privacyOptionsRequirementStatus: .required
        )
        let adService = AdService(adConsentService: consentService)

        adService.refreshPrivacyOptionsRequirement()

        #expect(adService.isPrivacyOptionsRequired)
    }

    @Test("Privacy choices state hides when consent service does not require options")
    @MainActor
    func privacyChoicesStateHidesWhenNotRequired() {
        let consentService = FakeAdConsentService(
            canRequestAds: false,
            privacyOptionsRequirementStatus: .notRequired
        )
        let adService = AdService(adConsentService: consentService)

        adService.refreshPrivacyOptionsRequirement()

        #expect(!adService.isPrivacyOptionsRequired)
    }

    @Test("Privacy choices presentation delegates to consent service")
    @MainActor
    func privacyChoicesPresentationDelegatesToConsentService() async {
        let consentService = FakeAdConsentService(
            canRequestAds: false,
            privacyOptionsRequirementStatus: .required
        )
        let adService = AdService(adConsentService: consentService)

        await adService.presentPrivacyOptionsForm()

        #expect(consentService.presentPrivacyOptionsCallCount == 1)
        #expect(adService.isPrivacyOptionsRequired)
    }

    @Test("Settings shows ad privacy choices only when required")
    func settingsShowsAdPrivacyChoicesOnlyWhenRequired() {
        #expect(SettingsView.showsAdPrivacyChoicesRow(isPrivacyOptionsRequired: true))
        #expect(!SettingsView.showsAdPrivacyChoicesRow(isPrivacyOptionsRequired: false))
    }

    @Test("Info plist includes ATT and SKAdNetwork privacy configuration")
    func infoPlistIncludesAdPrivacyConfiguration() {
        let info = Bundle.main.infoDictionary ?? [:]

        #expect((info["NSUserTrackingUsageDescription"] as? String)?.isEmpty == false)

        let skAdNetworkItems = info["SKAdNetworkItems"] as? [[String: String]]
        let identifiers = skAdNetworkItems?.compactMap { $0["SKAdNetworkIdentifier"] } ?? []

        #expect(identifiers.contains("cstr6suwn9.skadnetwork"))
        #expect(identifiers.count >= 50)
    }
}

@MainActor
private final class FakeAdConsentService: AdConsentPreparing {
    private let canRequestAds: Bool
    let privacyOptionsRequirementStatus: AdPrivacyOptionsRequirementStatus
    private(set) var prepareCallCount = 0
    private(set) var presentPrivacyOptionsCallCount = 0

    init(
        canRequestAds: Bool,
        privacyOptionsRequirementStatus: AdPrivacyOptionsRequirementStatus = .notRequired
    ) {
        self.canRequestAds = canRequestAds
        self.privacyOptionsRequirementStatus = privacyOptionsRequirementStatus
    }

    func prepareForAds() async -> Bool {
        prepareCallCount += 1
        return canRequestAds
    }

    func presentPrivacyOptionsForm() async {
        presentPrivacyOptionsCallCount += 1
    }
}
