import Foundation

enum AnalyticsConsent: String {
    case accepted
    case declined

    static let storageKey = "analytics.consent.v1"

    static func savedChoice(in defaults: UserDefaults = .standard) -> AnalyticsConsent? {
        defaults.string(forKey: storageKey).flatMap(AnalyticsConsent.init(rawValue:))
    }
}
