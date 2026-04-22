import Foundation

/// App-wide user preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let backwordLetterFeedback = "backwordLetterFeedback"
        static let crosswordCorrectHighlight = "crosswordCorrectHighlight"
    }

    /// Pro-only: highlight letters in past guesses that appear anywhere in the target word.
    @Published var backwordLetterFeedback: Bool {
        didSet { UserDefaults.standard.set(backwordLetterFeedback, forKey: Keys.backwordLetterFeedback) }
    }

    /// When enabled, cells flash green when a crossword answer is completed correctly.
    @Published var crosswordCorrectHighlight: Bool {
        didSet { UserDefaults.standard.set(crosswordCorrectHighlight, forKey: Keys.crosswordCorrectHighlight) }
    }

    private init() {
        backwordLetterFeedback = UserDefaults.standard.bool(forKey: Keys.backwordLetterFeedback)
        let stored = UserDefaults.standard.object(forKey: Keys.crosswordCorrectHighlight)
        crosswordCorrectHighlight = stored != nil ? UserDefaults.standard.bool(forKey: Keys.crosswordCorrectHighlight) : true
    }
}
