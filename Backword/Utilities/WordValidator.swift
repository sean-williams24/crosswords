import UIKit

enum WordValidator {
    private static let checker = UITextChecker()
    private static let supportedLanguages = ["en_US", "en_GB"]

    /// Returns `true` if the word is recognised by either supported English dictionary.
    static func isValidEnglishWord(_ word: String) -> Bool {
        let lowercased = word.lowercased()
        let range = NSRange(location: 0, length: lowercased.utf16.count)

        return supportedLanguages.contains { language in
            let misspelledRange = checker.rangeOfMisspelledWord(
                in: lowercased,
                range: range,
                startingAt: 0,
                wrap: false,
                language: language
            )
            return misspelledRange.location == NSNotFound
        }
    }
}
