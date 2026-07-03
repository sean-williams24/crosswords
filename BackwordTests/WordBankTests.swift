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

    @Test("No duplicate or wrapper-equivalent fields")
    func noDuplicateOrWrapperEquivalentFields() throws {
        for obj in try loadWordBank() {
            let fields = fieldValues(for: obj)
            for leftIndex in fields.indices {
                for rightIndex in fields.indices where rightIndex > leftIndex {
                    #expect(
                        fields[leftIndex].value != fields[rightIndex].value,
                        "\(fields[leftIndex].name) == \(fields[rightIndex].name) for word: \(obj.word) -> \(fields[leftIndex].value)"
                    )
                    #expect(
                        normalizedClueIdea(fields[leftIndex].value) != normalizedClueIdea(fields[rightIndex].value),
                        "\(fields[leftIndex].name) repeats clue idea from \(fields[rightIndex].name) for word: \(obj.word) -> \(fields[leftIndex].value) / \(fields[rightIndex].value)"
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
                        !leaksAnswerFragment(field.value, term),
                        "\(field.name) contains answer term for word: \(obj.word) term: \(term) field: \(field.value)"
                    )
                }
            }
        }
    }

    @Test("Known derivability examples are rejected")
    func knownDerivabilityExamplesAreRejected() {
        #expect(leaksAnswerFragment("Suitcase or legal matter", "CASE"))
        #expect(!leaksAnswerFragment("A strong start", "ART"))
        #expect(isAnswerDerivable(answer: "TENTH", clue: "One part of ten equal divisions"))
        #expect(isAnswerDerivable(answer: "BAGGED", clue: "Put into a bag"))
        #expect(isAnswerDerivable(answer: "SMOKER", clue: "One who smokes"))
        #expect(isAnswerDerivable(answer: "ARTY", clue: "Pretentiously artistic"))
        #expect(isAnswerDerivable(answer: "RUNNER", clue: "One who runs"))
        #expect(isAnswerDerivable(answer: "RESULTING", clue: "Resultant of previous events"))
    }

    @Test("Known wrapper-equivalent clue examples are rejected")
    func knownWrapperEquivalentClueExamplesAreRejected() {
        #expect(normalizedClueIdea("Maybe burning fiercely") == "burning fiercely")
        #expect(normalizedClueIdea("Burning fiercely, perhaps") == "burning fiercely")
        #expect(normalizedClueIdea("Burning fiercely?") == "burning fiercely")
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

    @Test("No word bank clues end in full stops")
    func noWordBankCluesEndInFullStops() throws {
        for obj in try loadWordBank() {
            for field in fieldValues(for: obj) {
                let trimmedValue = field.value.trimmingCharacters(in: .whitespacesAndNewlines)

                #expect(
                    !trimmedValue.hasSuffix("."),
                    "\(field.name) ends in a full stop for word: \(obj.word) field: \(field.value)"
                )
            }
        }
    }

    @Test("No active clue fields use filler qualifiers")
    func noActiveClueFieldsUseFillerQualifiers() throws {
        let pattern = #"(?i)\b(perhaps|maybe|possibly|sometimes|loosely)\b"#
        let regex = try #require(try? NSRegularExpression(pattern: pattern))

        for obj in try loadWordBank() {
            for field in fieldValues(for: obj) {
                let range = NSRange(field.value.startIndex..<field.value.endIndex, in: field.value)
                #expect(
                    regex.firstMatch(in: field.value, range: range) == nil,
                    "\(field.name) uses filler qualifier for word: \(obj.word) field: \(field.value)"
                )
            }
        }
    }

    @Test("Abbreviation clues are marked")
    func abbreviationCluesAreMarked() throws {
        let wordBank = try loadWordBank()
        let foundWords = Set(wordBank.map { $0.word.uppercased() })
        let missingWords = Self.abbreviationWords.subtracting(foundWords)

        #expect(missingWords.isEmpty, "Abbreviation test words missing from word bank: \(missingWords.sorted())")

        for obj in wordBank where Self.abbreviationWords.contains(obj.word.uppercased()) {
            for field in fieldValues(for: obj) {
                #expect(
                    field.value.hasSuffix(" (abbr)"),
                    "\(field.name) is missing abbreviation marker for word: \(obj.word) field: \(field.value)"
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

    private func leaksAnswerFragment(_ haystack: String, _ needle: String) -> Bool {
        let compactHaystack = compact(haystack)
        let compactNeedle = compact(needle)
        return compactNeedle.count >= 4 && compactHaystack.contains(compactNeedle)
    }

    private func normalizedClueIdea(_ clue: String) -> String {
        var text = clue.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        var changed = true
        while changed {
            let before = text
            text = text.replacingOccurrences(
                of: #"(?i)^(could be|maybe|often|seen as|associated with|a sign of|possibly|perhaps|sometimes|loosely|for one|think of|another way to say|kind of|type of)\s+"#,
                with: "",
                options: .regularExpression
            )
            text = text.replacingOccurrences(
                of: #"(?i),?\s*(perhaps|maybe|sometimes|loosely|for one|in a way|of sorts)$"#,
                with: "",
                options: .regularExpression
            )
            text = text.trimmingCharacters(in: CharacterSet(charactersIn: " .?!"))
            changed = text != before
        }

        text = text.replacingOccurrences(of: "___", with: " blank ")
        text = text.replacingOccurrences(of: #"['’]s\b"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: [.regularExpression, .caseInsensitive])
        return text.lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func compact(_ text: String) -> String {
        text.lowercased().replacingOccurrences(
            of: #"[^a-z0-9]+"#,
            with: "",
            options: .regularExpression
        )
    }

    private func singularize(_ word: String) -> String {
        if word.count > 4 && word.hasSuffix("ies") {
            return String(word.dropLast(3)) + "y"
        }
        if word.count > 4 && word.hasSuffix("es") && String(word.dropLast()).hasSuffix("e") {
            return String(word.dropLast())
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
        let ordinalRoots = [
            "first": "one", "second": "two", "third": "three", "fourth": "four",
            "fifth": "five", "sixth": "six", "seventh": "seven", "eighth": "eight",
            "ninth": "nine", "tenth": "ten", "eleventh": "eleven", "twelfth": "twelve",
            "thirteenth": "thirteen", "fourteenth": "fourteen", "fifteenth": "fifteen",
            "sixteenth": "sixteen", "seventeenth": "seventeen", "eighteenth": "eighteen",
            "nineteenth": "nineteen", "twentieth": "twenty",
        ]
        let suffixes = ["ed", "ing", "er", "or", "ist", "ian", "istic", "ical", "ic", "y", "ness", "ity", "tion"]
        var roots: Set<String> = []
        if let ordinalRoot = ordinalRoots[word], rootIsSafe(ordinalRoot) {
            roots.insert(ordinalRoot)
        }
        for suffix in suffixes where word.count > suffix.count + 2 && word.hasSuffix(suffix) {
            let root = String(word.dropLast(suffix.count))
            var candidates: Set<String> = [root]
            if root.count >= 2 && root.last == root.dropLast().last {
                candidates.insert(String(root.dropLast()))
            }
            if ["ed", "er", "or", "istic", "ical", "ic"].contains(suffix) {
                candidates.insert(root + "e")
            }
            if suffix == "y" {
                candidates = candidates.filter { Self.safeShortRoots.contains($0) }
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
        if word.count > 5 && (word.hasSuffix("ant") || word.hasSuffix("ent")) {
            roots.insert(String(word.dropLast(3)))
        }
        if word.count > 3 && word.hasSuffix("y") {
            roots.insert(String(word.dropLast()))
        }
        return roots.filter(rootIsSafe)
    }

    private func rootIsSafe(_ root: String) -> Bool {
        root.count >= 4 || Self.safeShortRoots.contains(root)
    }

    private static let safeShortRoots: Set<String> = ["art", "bag", "run", "ten"]

    private static let stopwords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "in", "into",
        "is", "it", "of", "on", "one", "or", "that", "the", "thing", "to", "who", "with",
    ]

    private static let abbreviationWords: Set<String> = [
        "ABC", "ABS", "ALT", "APR", "ATF", "ATM", "AWOL", "BBC", "BBQ", "BFF",
        "BLM", "BLT", "BMW", "BMX", "BRB", "BTW", "CBS", "CDS", "CEO", "CGI",
        "CNN", "CSI", "DIY", "DJS", "DNA", "DUI", "DVD", "ESL", "ETC",
        "FAQ", "FBI", "FCC", "FWD", "FYI", "GOP", "GPA", "GPS", "HBO", "HIV",
        "IBM", "IOS", "IPA", "IRS", "IUD", "JFK", "JLO", "JPG", "KFC", "KGB",
        "LAX", "LBJ", "LCD", "LEED", "LOL", "MGM", "MIC", "MMA", "MRS", "MSG",
        "MTV", "MVP", "NBA", "NBC", "NFL", "NHL", "NPR", "NRA", "NYE", "NYT",
        "OCD", "OMG", "ORG", "PBS", "PDF", "PGA", "PHD", "PJS", "REM", "RNA",
        "SCOTUS", "SMS", "SOS", "SUV", "TBD", "TBS", "TKO", "TLC", "TNT", "TSA",
        "TSP", "UPC", "UPS", "VIP", "WWE", "WWI",
    ]
}
