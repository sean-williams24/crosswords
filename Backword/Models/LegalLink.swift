import Foundation

struct LegalLink: Equatable, Identifiable {
    let title: String
    let url: URL

    var id: String { url.absoluteString }

    static let privacyPolicy = LegalLink(
        title: "Privacy Policy",
        url: AppBrand.website.appendingPathComponent("privacy")
    )

    static let termsOfUse = LegalLink(
        title: "Terms of Use",
        url: AppBrand.website.appendingPathComponent("terms")
    )

    static let privacyChoices = LegalLink(
        title: "Privacy Choices",
        url: AppBrand.website.appendingPathComponent("privacy-choices")
    )

    static let all: [LegalLink] = [
        .privacyPolicy,
        .privacyChoices,
        .termsOfUse
    ]
}
