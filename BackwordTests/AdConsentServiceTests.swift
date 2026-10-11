import Foundation
import Testing
@testable import Backword

@Suite("Ad consent startup")
struct AdConsentServiceTests {
    @Test("Launch refresh updates privacy choices without starting ads or prompting")
    @MainActor
    func launchRefreshIsSilent() async {
        let consentService = FakeAdConsentService(
            canRequestAds: false,
            privacyOptionsRequirementStatus: .required
        )
        let adService = AdService(adConsentService: consentService)

        await adService.refreshConsentStatusIfNeeded()
        await adService.refreshConsentStatusIfNeeded()
        await adService.loadRewardedAd()

        #expect(consentService.updateCallCount == 1)
        #expect(consentService.prepareCallCount == 0)
        #expect(consentService.presentPrivacyOptionsCallCount == 0)
        #expect(adService.isPrivacyOptionsRequired)
        #expect(!adService.adStartupDidComplete)
        #expect(!adService.isPresentingFullScreenAd)
    }

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
        #expect(consentService.updateCallCount == 1)
        #expect(consentService.prepareCallCount == 1)
        #expect(adService.isPrivacyOptionsRequired)
        #expect(adService.adStartupDidComplete)
        #expect(!adService.isPresentingFullScreenAd)
    }

    @Test("Concurrent ad requests wait for the same consent interaction")
    @MainActor
    func concurrentAdRequestsShareConsentPreparation() async {
        let consentService = FakeAdConsentService(canRequestAds: false, pausesPreparation: true)
        let adService = AdService(adConsentService: consentService)
        let firstRequest = Task { await adService.prepareAdsIfNeeded() }
        await consentService.waitForPreparationToStart()

        let secondRequest = Task { await adService.prepareAdsIfNeeded() }
        await Task.yield()
        #expect(consentService.prepareCallCount == 1)
        #expect(!adService.adStartupDidComplete)

        consentService.finishPreparation()
        #expect(!(await firstRequest.value))
        #expect(!(await secondRequest.value))
        #expect(consentService.updateCallCount == 1)
        #expect(consentService.prepareCallCount == 1)
        #expect(adService.adStartupDidComplete)
    }

    @Test("Interstitial gate continues when consent startup is not ready")
    @MainActor
    func interstitialGateContinuesWhenConsentStartupIsNotReady() {
        let consentService = FakeAdConsentService(canRequestAds: false)
        let adService = AdService(adConsentService: consentService, preGameInterstitialsEnabled: true)
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

    @Test("Settings offers Subscribe only to non-Pro users")
    func settingsSubscribeVisibility() {
        #expect(SettingsSubscribeButtonVisibility.shouldShow(isProUser: false))
        #expect(!SettingsSubscribeButtonVisibility.shouldShow(isProUser: true))
    }

    @Test("Settings hides its Pro benefit message for StoreKit Pro users")
    func settingsSubscribeFooterVisibility() {
        #expect(SettingsSubscribeFooterVisibility.shouldShow(isProUser: false))
        #expect(!SettingsSubscribeFooterVisibility.shouldShow(isProUser: true))
    }

    @Test("Settings Account and Subscribe icons share an aligned column")
    func settingsSubscribeIconLayout() {
        #expect(SettingsSubscribeRowLayout.iconColumnWidth == 44)
        #expect(SettingsSubscribeRowLayout.proLogoHeight == 22)
        #expect(SettingsSubscribeRowLayout.proLogoScale > 1)
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
    private let pausesPreparation: Bool
    private var preparationStartedContinuation: CheckedContinuation<Void, Never>?
    private var preparationContinuations: [CheckedContinuation<Void, Never>] = []
    let privacyOptionsRequirementStatus: AdPrivacyOptionsRequirementStatus
    private(set) var prepareCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var presentPrivacyOptionsCallCount = 0

    init(
        canRequestAds: Bool,
        privacyOptionsRequirementStatus: AdPrivacyOptionsRequirementStatus = .notRequired,
        pausesPreparation: Bool = false
    ) {
        self.canRequestAds = canRequestAds
        self.privacyOptionsRequirementStatus = privacyOptionsRequirementStatus
        self.pausesPreparation = pausesPreparation
    }

    func updateConsentInfo() async -> Bool {
        updateCallCount += 1
        return true
    }

    func prepareForAds() async -> Bool {
        prepareCallCount += 1
        preparationStartedContinuation?.resume()
        preparationStartedContinuation = nil
        if pausesPreparation {
            await withCheckedContinuation { preparationContinuations.append($0) }
        }
        return canRequestAds
    }

    func presentPrivacyOptionsForm() async {
        presentPrivacyOptionsCallCount += 1
    }

    func waitForPreparationToStart() async {
        guard prepareCallCount == 0 else { return }
        await withCheckedContinuation { preparationStartedContinuation = $0 }
    }

    func finishPreparation() {
        let continuations = preparationContinuations
        preparationContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}
