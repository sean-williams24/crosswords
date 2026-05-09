import UIKit

enum WordValidator {
    private static let checker = UITextChecker()

    /// Returns `true` if the word is recognised by the system English dictionary.
    static func isValidEnglishWord(_ word: String) -> Bool {
        let lowercased = word.lowercased()
        let range = NSRange(location: 0, length: lowercased.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(
            in: lowercased,
            range: range,
            startingAt: 0,
            wrap: false,
            language: "en"
        )
        return misspelledRange.location == NSNotFound
    }
}
