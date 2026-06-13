import Foundation
import Testing

@Suite("Word bank clue safety")
struct WordBankTests {
    struct WordObject: Decodable {
        let word: String
        let text: String?
        let hint: String?
        let hard_text: String?
        let hardText: String?
        let clues: [String]?
    }

    struct FieldValue {
        let name: String
        let value: String
    }

    @Test("No exact duplicate fields")
    func noExactDuplicateFields() throws {
        for obj in try loadWordBank() {
            let fields = fieldValues(for: obj)
            for leftIndex in fields.indices {
                for rightIndex in fields.indices where rightIndex > leftIndex {
                    #expect(
                        fields[leftIndex].value != fields[rightIndex].value,
                        "\(fields[leftIndex].name) == \(fields[rightIndex].name) for word: \(obj.word) -> \(fields[leftIndex].value)"
                    )
                }
            }
        }
    }

    @Test("No field contains answer or multi-word constituent")
    func noFieldContainsAnswerOrConstituent() throws {
        for obj in try loadWordBank() {
            let terms = answerTerms(for: obj.word)
            for field in fieldValues(for: obj) {
                for term in terms {
                    #expect(
                        !isWholeWord(field.value, term),
                        "\(field.name) contains answer term for word: \(obj.word) term: \(term) field: \(field.value)"
                    )
                }
            }
        }
    }

    @Test("Known derivability examples are rejected")
    func knownDerivabilityExamplesAreRejected() {
        #expect(isAnswerDerivable(answer: "SMOKER", clue: "One who smokes"))
        #expect(isAnswerDerivable(answer: "ARTY", clue: "Pretentiously artistic"))
        #expect(isAnswerDerivable(answer: "RUNNER", clue: "One who runs"))
    }

    @Test("No word bank clue is answer derivable")
    func noWordBankClueIsAnswerDerivable() throws {
        for obj in try loadWordBank() {
            for field in fieldValues(for: obj) {
                #expect(
                    !isAnswerDerivable(answer: obj.word, clue: field.value),
                    "\(field.name) is answer-derivable for word: \(obj.word) field: \(field.value)"
                )
            }
        }
    }

    private func loadWordBank() throws -> [WordObject] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Backend/word_bank.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([WordObject].self, from: data)
    }

    private func fieldValues(for obj: WordObject) -> [FieldValue] {
        var fields: [FieldValue] = []
        if let text = obj.text, !text.isEmpty {
            fields.append(FieldValue(name: "text", value: text))
        }
        if let hint = obj.hint, !hint.isEmpty {
            fields.append(FieldValue(name: "hint", value: hint))
        }
        if let hardText = obj.hard_text, !hardText.isEmpty {
            fields.append(FieldValue(name: "hard_text", value: hardText))
        }
        if let hardText = obj.hardText, !hardText.isEmpty {
            fields.append(FieldValue(name: "hardText", value: hardText))
        }
        for (index, clue) in (obj.clues ?? []).enumerated() where !clue.isEmpty {
            fields.append(FieldValue(name: "clues[\(index)]", value: clue))
        }
        return fields
    }

    private func answerTerms(for answer: String) -> [String] {
        let parts = tokens(answer)
        guard !parts.isEmpty else { return [] }
        var terms = [parts.joined(separator: " ")]
        if parts.count > 1 {
            terms.append(contentsOf: parts.filter { $0.count >= 3 })
        }
        return terms
    }

    private func isWholeWord(_ haystack: String, _ needle: String) -> Bool {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: needle.lowercased()) + "\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let lowered = haystack.lowercased()
        let range = NSRange(location: 0, length: (lowered as NSString).length)
        return regex.firstMatch(in: lowered, options: [], range: range) != nil
    }

    private func isAnswerDerivable(answer: String, clue: String) -> Bool {
        for term in answerTerms(for: answer) where isWholeWord(clue, term) {
            return true
        }

        let answerTokens = tokens(answer).filter { !Self.stopwords.contains($0) }
        let clueRootSets = tokens(clue)
            .filter { !Self.stopwords.contains($0) }
            .map { clueRoots($0) }

        for answerToken in answerTokens {
            for root in answerRoots(answerToken) {
                if clueRootSets.contains(where: { $0.contains(root) }) {
                    return true
                }
            }
        }

        return false
    }

    private func tokens(_ text: String) -> [String] {
        let lowered = text.lowercased().replacingOccurrences(of: "'s", with: "")
        let normalized = lowered.replacingOccurrences(
            of: #"[^a-z0-9]+"#,
            with: " ",
            options: .regularExpression
        )
        return normalized.split(separator: " ").map(String.init)
    }

    private func singularize(_ word: String) -> String {
        if word.count > 4 && word.hasSuffix("ies") {
            return String(word.dropLast(3)) + "y"
        }
        if word.count > 3 && word.hasSuffix("es") {
            return String(word.dropLast(2))
        }
        if word.count > 3 && word.hasSuffix("s") {
            return String(word.dropLast())
        }
        return word
    }

    private func verbBase(_ word: String) -> String {
        let singular = singularize(word)
        if singular.count > 5 && singular.hasSuffix("ing") {
            var base = String(singular.dropLast(3))
            if base.count >= 2 && base.last == base.dropLast().last {
                base = String(base.dropLast())
            }
            return base
        }
        if singular.count > 4 && singular.hasSuffix("ed") {
            var base = String(singular.dropLast(2))
            if base.count >= 2 && base.last == base.dropLast().last {
                base = String(base.dropLast())
            }
            return base
        }
        return singular
    }

    private func answerRoots(_ answerToken: String) -> Set<String> {
        let word = singularize(answerToken)
        let suffixes = ["er", "or", "ist", "ian", "istic", "ical", "ic", "y", "ness", "ity", "tion"]
        var roots: Set<String> = []
        for suffix in suffixes where word.count > suffix.count + 2 && word.hasSuffix(suffix) {
            let root = String(word.dropLast(suffix.count))
            var candidates: Set<String> = [root]
            if root.count >= 2 && root.last == root.dropLast().last {
                candidates.insert(String(root.dropLast()))
            }
            if ["er", "or", "istic", "ical", "ic"].contains(suffix) {
                candidates.insert(root + "e")
            }
            roots.formUnion(candidates.filter(rootIsSafe))
        }
        return roots
    }

    private func clueRoots(_ clueToken: String) -> Set<String> {
        let word = verbBase(clueToken)
        var roots: Set<String> = [word]
        if word.count > 5 && word.hasSuffix("istic") {
            roots.insert(String(word.dropLast(5)))
        }
        if word.count > 4 && word.hasSuffix("ical") {
            roots.insert(String(word.dropLast(4)))
            roots.insert(String(word.dropLast(4)) + "e")
        }
        if word.count > 3 && word.hasSuffix("ic") {
            roots.insert(String(word.dropLast(2)))
            roots.insert(String(word.dropLast(2)) + "e")
        }
        if word.count > 3 && word.hasSuffix("y") {
            roots.insert(String(word.dropLast()))
        }
        return roots.filter(rootIsSafe)
    }

    private func rootIsSafe(_ root: String) -> Bool {
        root.count >= 4 || root == "art" || root == "run"
    }

    private static let stopwords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "in", "into",
        "is", "it", "of", "on", "one", "or", "that", "the", "thing", "to", "who", "with",
    ]
}
