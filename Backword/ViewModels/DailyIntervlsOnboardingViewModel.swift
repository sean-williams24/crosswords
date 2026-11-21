import Combine
import Foundation

@MainActor
final class DailyIntervlsOnboardingViewModel: ObservableObject {
    private enum Stage: String {
        case gameplay
        case scoring
        case complete
    }

    private static let storageKey = "dailyIntervls.onboarding.v1"
    private let defaults: UserDefaults
    @Published private var stage: Stage

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        stage = defaults.string(forKey: Self.storageKey).flatMap(Stage.init(rawValue:)) ?? .gameplay
    }

    var pendingStep: DailyIntervlsGuideStep? {
        switch stage {
        case .gameplay: return .gameplay
        case .scoring: return .scoring
        case .complete: return nil
        }
    }

    func homeStep(isReady: Bool) -> DailyIntervlsGuideStep? {
        isReady ? pendingStep : nil
    }

    func acknowledgeGameplay() {
        guard stage == .gameplay else { return }
        save(.scoring)
    }

    func finishOnboarding() {
        guard stage == .scoring else { return }
        save(.complete)
    }

    private func save(_ stage: Stage) {
        defaults.set(stage.rawValue, forKey: Self.storageKey)
        self.stage = stage
    }

    #if DEBUG
    static func preview() -> DailyIntervlsOnboardingViewModel {
        let defaults = UserDefaults(suiteName: "DailyIntervlsOnboardingPreview")!
        defaults.set(Stage.complete.rawValue, forKey: storageKey)
        return DailyIntervlsOnboardingViewModel(defaults: defaults)
    }
    #endif
}
