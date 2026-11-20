import Combine
import Foundation

@MainActor
final class DailyIntervlsOnboardingViewModel: ObservableObject {
    enum HomeOffer: Equatable {
        case firstLaunch(DailyIntervlsGuideStep)
        case returningTip
    }

    private enum Stage: String {
        case gameplay
        case scoring
        case returningTipPending
        case complete
    }

    private static let storageKey = "dailyIntervls.onboarding.v1"
    private let defaults: UserDefaults
    @Published private var stage: Stage
    @Published private(set) var showsReturningTip = false

    init(defaults: UserDefaults = .standard, legacyAppDataExists: Bool? = nil) {
        self.defaults = defaults
        if let savedStage = defaults.string(forKey: Self.storageKey).flatMap(Stage.init(rawValue:)) {
            stage = savedStage
        } else {
            let hasPriorUse = Self.hasLegacyPreferences(in: defaults)
                || (legacyAppDataExists ?? Self.hasSavedAppData())
            let initialStage: Stage = hasPriorUse ? .returningTipPending : .gameplay
            stage = initialStage
            defaults.set(initialStage.rawValue, forKey: Self.storageKey)
        }
    }

    var firstLaunchStep: DailyIntervlsGuideStep? {
        switch stage {
        case .gameplay: return .gameplay
        case .scoring: return .scoring
        case .returningTipPending, .complete: return nil
        }
    }

    func homeOffer(isHomeReady: Bool, hasGameLoadError: Bool) -> HomeOffer? {
        guard isHomeReady else { return nil }
        if let firstLaunchStep {
            return .firstLaunch(firstLaunchStep)
        }
        return stage == .returningTipPending && !hasGameLoadError ? .returningTip : nil
    }

    func acknowledgeGameplay() {
        guard stage == .gameplay else { return }
        save(.scoring)
    }

    func finishOnboarding() {
        guard stage == .scoring else { return }
        save(.complete)
    }

    func presentReturningTip() {
        guard stage == .returningTipPending else { return }
        save(.complete)
        showsReturningTip = true
    }

    func dismissReturningTip() {
        showsReturningTip = false
    }

    private func save(_ stage: Stage) {
        defaults.set(stage.rawValue, forKey: Self.storageKey)
        self.stage = stage
    }

    private static func hasLegacyPreferences(in defaults: UserDefaults) -> Bool {
        let legacyKeys = [
            AnalyticsConsent.storageKey,
            "appColorScheme",
            "backword_progress_account_id",
            "Anagram.firstReleaseDate"
        ]
        return AppSettings.hasStoredPreferences(in: defaults)
            || legacyKeys.contains { defaults.object(forKey: $0) != nil }
    }

    private static func hasSavedAppData() -> Bool {
        let files = FileManager.default
        // Prior versions write rating and progress to Application Support and puzzle
        // content to Caches. Check before this launch can create either directory.
        return [.applicationSupportDirectory, .cachesDirectory].contains { directory in
            files.urls(for: directory, in: .userDomainMask).contains { root in
                files.fileExists(atPath: root.appendingPathComponent("Backword", isDirectory: true).path)
            }
        }
    }

    #if DEBUG
    static func preview() -> DailyIntervlsOnboardingViewModel {
        let defaults = UserDefaults(suiteName: "DailyIntervlsOnboardingPreview")!
        defaults.set(Stage.complete.rawValue, forKey: storageKey)
        return DailyIntervlsOnboardingViewModel(defaults: defaults)
    }
    #endif
}
