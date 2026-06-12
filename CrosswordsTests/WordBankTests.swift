import XCTest

final class WordBankTests: XCTestCase {
    struct WordObject: Decodable {
        let word: String
        let text: String?
        let hint: String?
        let hard_text: String?
        let clues: [String]?
    }

    var wordBank: [WordObject] = []

    override func setUpWithError() throws {
        let fileURL = URL(fileURLWithPath: "Backend/word_bank.json")
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        wordBank = try decoder.decode([WordObject].self, from: data)
    }

    func testNoExactDuplicateFields() throws {
        for obj in wordBank {
            let text = obj.text ?? ""
            let hard = obj.hard_text ?? ""
            XCTAssertNotEqual(text, hard, "text == hard_text for word: \(obj.word)")
            if let clues = obj.clues {
                for clue in clues {
                    XCTAssertNotEqual(text, clue, "text == clue for word: \(obj.word) -> \(clue)")
                    XCTAssertNotEqual(hard, clue, "hard_text == clue for word: \(obj.word) -> \(clue)")
                }
            }
        }
    }

    func isWholeWord(_ haystack: String, _ needle: String) -> Bool {
        // simple whole-word case-insensitive check
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: needle.lowercased()) + "\\b"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        return re.firstMatch(in: haystack.lowercased(), options: [], range: range) != nil
    }

    func testNoFieldContainsAnswerRoot() throws {
        for obj in wordBank {
            let word = obj.word.lowercased()
            let fields = [obj.text, obj.hint, obj.hard_text] + (obj.clues ?? [])
            for fieldOpt in fields {
                guard let field = fieldOpt else { continue }
                // fail if the answer word appears as a whole word inside any field
                if isWholeWord(field, word) {
                    XCTFail("field contains answer word root for word: \(obj.word) in field: \(field)")
                }
            }
        }
    }
}
