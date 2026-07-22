import Foundation

enum BackwordInstructionsPresentation: Equatable {
    case onboarding
    case rulesUpdate
    case manual
}

/// App-wide user preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let currentBackwordRulesVersion = 1

    private enum Keys {
        static let backwordLetterFeedback = "backwordLetterFeedback"
        static let crosswordCorrectHighlight = "crosswordCorrectHighlight"
        static let hasDismissedAdExplainer = "hasDismissedAdExplainer"
        static let hasSeenDailyCrosswordOnboarding = "hasSeenDailyCrosswordOnboarding"
        static let hasSeenBackwordOnboarding = "hasSeenBackwordOnboarding"
        static let lastSeenBackwordRulesVersion = "lastSeenBackwordRulesVersion"
    }

    private let userDefaults: UserDefaults

    /// Pro-only: highlight letters in past guesses that appear anywhere in the target word.
    @Published var backwordLetterFeedback: Bool {
        didSet { userDefaults.set(backwordLetterFeedback, forKey: Keys.backwordLetterFeedback) }
    }

    /// When enabled, correctly completed crossword cells are permanently highlighted green and locked from deletion.
    @Published var crosswordCorrectHighlight: Bool {
        didSet { userDefaults.set(crosswordCorrectHighlight, forKey: Keys.crosswordCorrectHighlight) }
    }

    /// When true, the interstitial ad explainer is skipped before daily games.
    @Published var hasDismissedAdExplainer: Bool {
        didSet { userDefaults.set(hasDismissedAdExplainer, forKey: Keys.hasDismissedAdExplainer) }
    }

    var hasSeenBackwordOnboarding: Bool {
        get { userDefaults.bool(forKey: Keys.hasSeenBackwordOnboarding) }
        set { userDefaults.set(newValue, forKey: Keys.hasSeenBackwordOnboarding) }
    }

    var lastSeenBackwordRulesVersion: Int {
        get { userDefaults.integer(forKey: Keys.lastSeenBackwordRulesVersion) }
        set { userDefaults.set(newValue, forKey: Keys.lastSeenBackwordRulesVersion) }
    }

    var hasSeenDailyCrosswordOnboarding: Bool {
        get { userDefaults.bool(forKey: Keys.hasSeenDailyCrosswordOnboarding) }
        set { userDefaults.set(newValue, forKey: Keys.hasSeenDailyCrosswordOnboarding) }
    }

    var automaticBackwordInstructionsPresentation: BackwordInstructionsPresentation? {
        if !hasSeenBackwordOnboarding {
            return .onboarding
        }
        if lastSeenBackwordRulesVersion < Self.currentBackwordRulesVersion {
            return .rulesUpdate
        }
        return nil
    }

    func markBackwordInstructionsSeen(_ presentation: BackwordInstructionsPresentation) {
        switch presentation {
        case .onboarding:
            hasSeenBackwordOnboarding = true
            lastSeenBackwordRulesVersion = Self.currentBackwordRulesVersion
        case .rulesUpdate:
            lastSeenBackwordRulesVersion = Self.currentBackwordRulesVersion
        case .manual:
            break
        }
    }

    func resetBackwordOnboarding() {
        hasSeenBackwordOnboarding = false
        lastSeenBackwordRulesVersion = 0
    }

    func resetBackwordRulesNotice() {
        hasSeenBackwordOnboarding = true
        lastSeenBackwordRulesVersion = 0
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        backwordLetterFeedback = userDefaults.bool(forKey: Keys.backwordLetterFeedback)
        let stored = userDefaults.object(forKey: Keys.crosswordCorrectHighlight)
        crosswordCorrectHighlight = stored != nil ? userDefaults.bool(forKey: Keys.crosswordCorrectHighlight) : true
        hasDismissedAdExplainer = userDefaults.bool(forKey: Keys.hasDismissedAdExplainer)
    }
}
