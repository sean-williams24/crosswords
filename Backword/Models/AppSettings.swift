import Foundation

enum BackwordMode: String, CaseIterable {
    case normal
    case easy
}

enum BackwordInstructionsPresentation: Equatable {
    case onboarding
    case rulesUpdate
    case manual
}

enum BackwordOnboardingStep: String, CaseIterable, Identifiable {
    case initialGuess
    case connectedLetters
    case freeReveals
    case scoring
    case stuckHint

    var id: String { rawValue }

    func text(for mode: BackwordMode) -> String {
        switch self {
        case .initialGuess:
            return "Guess the 6 letter word..."
        case .connectedLetters:
            return "Correctly placed letters reveal when they form an unbroken chain from the back of the word."
        case .freeReveals:
            switch mode {
            case .normal:
                return "If your guesses do not extend that chain, the second and third wrong guesses each reveal one more letter from the end."
            case .easy:
                return "If your guesses do not extend that chain, each wrong guess reveals one more letter from the back of the word."
            }
        case .scoring:
            return "The fewer guesses you need, the more points you score."
        case .stuckHint:
            return "If you're stuck, guess any word to reveal a letter."
        }
    }
}

/// App-wide user preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let currentBackwordRulesVersion = 4

    private enum Keys {
        static let backwordLetterFeedback = "backwordLetterFeedback"
        static let backwordMode = "backwordMode"
        static let crosswordCorrectHighlight = "crosswordCorrectHighlight"
        static let hasDismissedAdExplainer = "hasDismissedAdExplainer"
        static let hasSeenDailyCrosswordOnboarding = "hasSeenDailyCrosswordOnboarding"
        static let hasSeenBackwordOnboarding = "hasSeenBackwordOnboarding"
        static let dismissedBackwordOnboardingSteps = "dismissedBackwordOnboardingSteps"
        static let lastSeenBackwordRulesVersion = "lastSeenBackwordRulesVersion"
    }

    private let userDefaults: UserDefaults

    /// Pro-only: highlight letters in past guesses that appear anywhere in the target word.
    @Published var backwordLetterFeedback: Bool {
        didSet { userDefaults.set(backwordLetterFeedback, forKey: Keys.backwordLetterFeedback) }
    }

    /// Controls how quickly letters are revealed after incorrect Backword guesses.
    @Published var backwordMode: BackwordMode {
        didSet { userDefaults.set(backwordMode.rawValue, forKey: Keys.backwordMode) }
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

    /// Inline Backword onboarding stays until every individual instruction is acknowledged.
    var pendingBackwordOnboardingSteps: [BackwordOnboardingStep] {
        guard !hasSeenBackwordOnboarding else { return [] }
        let dismissedSteps = Set(
            userDefaults.stringArray(forKey: Keys.dismissedBackwordOnboardingSteps) ?? []
        )
        return BackwordOnboardingStep.allCases.filter { !dismissedSteps.contains($0.rawValue) }
    }

    var automaticBackwordInstructionsPresentation: BackwordInstructionsPresentation? {
        guard hasSeenBackwordOnboarding else { return nil }
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

    func dismissBackwordOnboardingStep(_ step: BackwordOnboardingStep) {
        guard !hasSeenBackwordOnboarding else { return }

        var dismissedSteps = Set(
            userDefaults.stringArray(forKey: Keys.dismissedBackwordOnboardingSteps) ?? []
        )
        dismissedSteps.insert(step.rawValue)
        let orderedSteps = BackwordOnboardingStep.allCases
            .map(\.rawValue)
            .filter(dismissedSteps.contains)
        userDefaults.set(orderedSteps, forKey: Keys.dismissedBackwordOnboardingSteps)

        if pendingBackwordOnboardingSteps.isEmpty {
            markBackwordInstructionsSeen(.onboarding)
        }
    }

    func resetBackwordOnboarding() {
        hasSeenBackwordOnboarding = false
        lastSeenBackwordRulesVersion = 0
        userDefaults.removeObject(forKey: Keys.dismissedBackwordOnboardingSteps)
    }

    func resetBackwordRulesNotice() {
        hasSeenBackwordOnboarding = true
        lastSeenBackwordRulesVersion = 0
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        backwordLetterFeedback = userDefaults.bool(forKey: Keys.backwordLetterFeedback)
        backwordMode = BackwordMode(
            rawValue: userDefaults.string(forKey: Keys.backwordMode) ?? ""
        ) ?? .easy
        let stored = userDefaults.object(forKey: Keys.crosswordCorrectHighlight)
        crosswordCorrectHighlight = stored != nil ? userDefaults.bool(forKey: Keys.crosswordCorrectHighlight) : true
        hasDismissedAdExplainer = userDefaults.bool(forKey: Keys.hasDismissedAdExplainer)
    }
}
