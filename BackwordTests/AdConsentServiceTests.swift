import Foundation
import Testing
@testable import Backword

@Suite("Ad consent startup")
struct AdConsentServiceTests {
    @Test("Ad startup stops when consent preparation cannot request ads")
    @MainActor
    func adStartupStopsWhenConsentPreparationFails() async {
        let consentService = FakeAdConsentService(canRequestAds: false)
        let adService = AdService(adConsentService: consentService)

        let canRequestAds = await adService.prepareAdsIfNeeded()

        #expect(!canRequestAds)
        #expect(consentService.prepareCallCount == 1)
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
    private(set) var prepareCallCount = 0

    init(canRequestAds: Bool) {
        self.canRequestAds = canRequestAds
    }

    func prepareForAds() async -> Bool {
        prepareCallCount += 1
        return canRequestAds
    }
}
