import Foundation

struct LegalLink: Equatable, Identifiable {
    let title: String
    let url: URL

    var id: String { url.absoluteString }

    static let privacyPolicy = LegalLink(
        title: "Privacy Policy",
        url: URL(string: "https://www.playbackword.com/privacy")!
    )

    static let termsOfUse = LegalLink(
        title: "Terms of Use",
        url: URL(string: "https://www.playbackword.com/terms")!
    )

    static let privacyChoices = LegalLink(
        title: "Privacy Choices",
        url: URL(string: "https://www.playbackword.com/privacy-choices")!
    )

    static let all: [LegalLink] = [
        .privacyPolicy,
        .privacyChoices,
        .termsOfUse
    ]
}
