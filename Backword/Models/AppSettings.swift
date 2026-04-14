import Foundation

/// App-wide user preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let backwordLetterFeedback = "backwordLetterFeedback"
    }

    /// Pro-only: highlight letters in past guesses that appear anywhere in the target word.
    @Published var backwordLetterFeedback: Bool {
        didSet { UserDefaults.standard.set(backwordLetterFeedback, forKey: Keys.backwordLetterFeedback) }
    }

    private init() {
        backwordLetterFeedback = UserDefaults.standard.bool(forKey: Keys.backwordLetterFeedback)
    }
}
