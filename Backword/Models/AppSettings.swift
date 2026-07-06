import Foundation

/// App-wide user preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let backwordLetterFeedback = "backwordLetterFeedback"
        static let crosswordCorrectHighlight = "crosswordCorrectHighlight"
        static let hasDismissedAdExplainer = "hasDismissedAdExplainer"
        static let hasSeenDailyCrosswordOnboarding = "hasSeenDailyCrosswordOnboarding"
    }

    /// Pro-only: highlight letters in past guesses that appear anywhere in the target word.
    @Published var backwordLetterFeedback: Bool {
        didSet { UserDefaults.standard.set(backwordLetterFeedback, forKey: Keys.backwordLetterFeedback) }
    }

    /// When enabled, correctly completed crossword cells are permanently highlighted green and locked from deletion.
    @Published var crosswordCorrectHighlight: Bool {
        didSet { UserDefaults.standard.set(crosswordCorrectHighlight, forKey: Keys.crosswordCorrectHighlight) }
    }

    /// When true, the interstitial ad explainer is skipped before daily games.
    @Published var hasDismissedAdExplainer: Bool {
        didSet { UserDefaults.standard.set(hasDismissedAdExplainer, forKey: Keys.hasDismissedAdExplainer) }
    }

    var hasSeenBackwordOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenBackwordOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenBackwordOnboarding") }
    }

    var hasSeenDailyCrosswordOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasSeenDailyCrosswordOnboarding) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasSeenDailyCrosswordOnboarding) }
    }

    private init() {
        backwordLetterFeedback = UserDefaults.standard.bool(forKey: Keys.backwordLetterFeedback)
        let stored = UserDefaults.standard.object(forKey: Keys.crosswordCorrectHighlight)
        crosswordCorrectHighlight = stored != nil ? UserDefaults.standard.bool(forKey: Keys.crosswordCorrectHighlight) : true
        hasDismissedAdExplainer = UserDefaults.standard.bool(forKey: Keys.hasDismissedAdExplainer)
    }
}
