import Testing
@testable import Backword

@Suite("Legal links")
struct LegalLinkTests {
    @Test("Includes privacy policy and terms links")
    func includesRequiredLinks() {
        #expect(LegalLink.all == [.privacyPolicy, .termsOfUse])
    }

    @Test("Privacy policy points to Backword website")
    func privacyPolicyURL() {
        #expect(LegalLink.privacyPolicy.title == "Privacy Policy")
        #expect(LegalLink.privacyPolicy.url.absoluteString == "https://backword.vercel.app/privacy")
    }

    @Test("Terms use Apple's standard EULA")
    func termsURL() {
        #expect(LegalLink.termsOfUse.title == "Terms of Use")
        #expect(LegalLink.termsOfUse.url.absoluteString == "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    }
}
