import Combine
import Foundation

@MainActor
final class AnalyticsConsentViewModel: ObservableObject {
    @Published private(set) var choice: AnalyticsConsent?
    private let defaults: UserDefaults
    private let applyConsent: (Bool) -> Void

    var shouldShowPrompt: Bool { choice == nil }
    var isEnabled: Bool { choice == .accepted }

    init(
        defaults: UserDefaults = .standard,
        applyConsent: @escaping (Bool) -> Void
    ) {
        self.defaults = defaults
        self.applyConsent = applyConsent
        choice = AnalyticsConsent.savedChoice(in: defaults)
        applyConsent(choice == .accepted)
    }

    func setEnabled(_ enabled: Bool) {
        let next: AnalyticsConsent = enabled ? .accepted : .declined
        defaults.set(next.rawValue, forKey: AnalyticsConsent.storageKey)
        applyConsent(enabled)
        choice = next
    }
}
