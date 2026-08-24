import Testing
@testable import Backword

@Suite("Legal links")
struct LegalLinkTests {
    @Test("Includes privacy policy, privacy choices, and terms links")
    func includesRequiredLinks() {
        #expect(LegalLink.all == [.privacyPolicy, .privacyChoices, .termsOfUse])
    }

    @Test("Privacy policy points to Backword website")
    func privacyPolicyURL() {
        #expect(LegalLink.privacyPolicy.title == "Privacy Policy")
        #expect(LegalLink.privacyPolicy.url.absoluteString == "https://www.playbackword.com/privacy")
    }

    @Test("Privacy choices point to Backword website")
    func privacyChoicesURL() {
        #expect(LegalLink.privacyChoices.title == "Privacy Choices")
        #expect(LegalLink.privacyChoices.url.absoluteString == "https://www.playbackword.com/privacy-choices")
    }

    @Test("Terms point to Backword website")
    func termsURL() {
        #expect(LegalLink.termsOfUse.title == "Terms of Use")
        #expect(LegalLink.termsOfUse.url.absoluteString == "https://www.playbackword.com/terms")
    }
}
