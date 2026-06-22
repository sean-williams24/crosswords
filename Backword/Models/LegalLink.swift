import Foundation

struct LegalLink: Equatable, Identifiable {
    let title: String
    let url: URL

    var id: String { url.absoluteString }

    static let privacyPolicy = LegalLink(
        title: "Privacy Policy",
        url: URL(string: "https://backword.vercel.app/privacy")!
    )

    static let termsOfUse = LegalLink(
        title: "Terms of Use",
        url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    )

    static let all: [LegalLink] = [
        .privacyPolicy,
        .termsOfUse
    ]
}
