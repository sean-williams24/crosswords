import Testing
@testable import Backword

@Suite("Rating account Pro status presentation")
struct RatingAccountProStatusPresentationTests {
    @Test("Active status leaves the Pro label to the logo")
    func activeStatusUsesLogoAsTheProLabel() {
        #expect(RatingAccountProStatusPresentation.activeAccountTitle == "is active for this account")
        #expect(RatingAccountProStatusPresentation.activePhoneTitle == "is active on this iPhone")
        #expect(RatingAccountProStatusPresentation.logoTrailingAdjustment == -14)
    }

    @Test("Active status remains explicit for assistive technologies")
    func activeStatusAccessibilityIncludesPro() {
        #expect(RatingAccountProStatusPresentation.activeAccountAccessibilityLabel == "Pro is active for this account")
        #expect(RatingAccountProStatusPresentation.activePhoneAccessibilityLabel == "Pro is active on this iPhone")
    }
}
