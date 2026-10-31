import Foundation
import Testing
@testable import Backword

@Suite("Intervls identity and upgrade compatibility")
struct IntervlsBrandTests {
    @Test("Home uses half the standard wordmark height")
    func homeLogoSizing() {
        #expect(AppLayout.brandHomeLogoHeight == 19)
        #expect(AppLayout.brandHomeLogoHeight * 2 == AppLayout.brandLogoHeight)
    }

    @Test("Home PRO clears the wordmark and slightly overhangs at scaled sizes", arguments: [1.0, 1.5, 2.0])
    func homeProPlacement(scale: Double) {
        // Check the painted edge inside the original padded 1024×524 bitmap.
        let height = Double(AppLayout.homeProLogoHeight) * scale
        let gap = Double(AppLayout.homeProLogoSpacing) * scale + 171 / 524.0 * height
        let overhang = Double(AppLayout.homeProLogoTrailingOffset) * scale - 280 / 524.0 * height

        #expect(gap >= 2 * scale)
        #expect(gap <= 3 * scale)
        #expect(overhang >= 3 * scale)
        #expect(overhang <= 4 * scale)
    }

    @Test("Paywall PRO stays below the wordmark with a small trailing overhang", arguments: [1.0, 1.09])
    func paywallProPlacement(animationScale: Double) {
        // The original 1024×524 PRO bitmap has visible bounds x: 282...744,
        // y: 171...332. Check the painted lettering, including its breathing animation.
        let height = Double(AppLayout.paywallProLogoHeight)
        let width = height * 1024 / 524
        let gap = Double(AppLayout.paywallProLogoSpacing) + height / 2
            + (171 - 262) / 524.0 * height * animationScale
        let overhang = Double(AppLayout.paywallProLogoTrailingOffset) - width / 2
            + (744 - 512) / 524.0 * height * animationScale

        #expect(gap >= 4)
        #expect(gap <= 8)
        #expect(overhang >= 4)
        #expect(overhang <= 12)
    }

    @Test("Public URLs and overall brand use Intervls")
    func publicIdentity() {
        #expect(AppBrand.name == "Intervls")
        #expect(AppBrand.proName == "Intervls Pro")
        #expect(AppBrand.website.absoluteString == "https://intervls.com")
        #expect(AppBrand.logoAsset != "BackWordLogo")
        #expect(AppBrand.shareLogoAsset != "BackWordLogoShare")
        #expect(LegalLink.all.allSatisfy { $0.url.host == AppBrand.websiteHost })
    }

    @Test("Renamed app retains both existing subscription products")
    @MainActor func subscriptionCompatibility() {
        #expect(StoreService.monthlyID == "com.backword.monthlypro")
        #expect(StoreService.annualID == "com.backword.annualpro")
    }

    @Test("Legacy account-link errors are still recognised after the rename")
    func legacyErrorCompatibility() {
        #expect(AccountEntitlementPresentation.isAlreadyLinkedPurchaseError("This purchase belongs to a different Backword account."))
        #expect(AccountEntitlementPresentation.isAlreadyLinkedPurchaseError("This subscription is already linked to another Backword account."))
        #expect(AccountEntitlementPresentation.linkedElsewhereExplanation.contains("Intervls account"))
    }
}
