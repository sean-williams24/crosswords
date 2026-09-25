import Foundation

struct AnagramPuzzle: Codable, Identifiable, Equatable {
    let id: String
    let date: String
    let puzzleNumber: Int
    let schemaVersion: Int
    let answer: String
    let acceptedAnswers: [String]
    let initialScramble: String

    var length: Int { answer.count }
    var answers: [String] { [answer] + acceptedAnswers }

    var isValid: Bool {
        guard schemaVersion == 1, (7...9).contains(length),
              answer.allSatisfy({ $0.isASCII && $0.isUppercase }),
              initialScramble.count == length,
              initialScramble.sorted() == answer.sorted() else { return false }
        return Set(answers).count == answers.count
            && acceptedAnswers.allSatisfy {
                $0.count == length
                    && $0.allSatisfy { $0.isASCII && $0.isUppercase }
                    && $0.sorted() == answer.sorted()
            }
            && !answers.contains(initialScramble)
    }

    /// Review content has no published date and cannot earn rating points.
    #if DEBUG
    static let review = AnagramPuzzle(
        id: "00000000-0000-0000-0000-000000000000",
        date: "review",
        puzzleNumber: 0,
        schemaVersion: 1,
        answer: "TRIANGLE",
        acceptedAnswers: ["INTEGRAL"],
        initialScramble: "RAGTLINE"
    )
    #endif
}

struct AnagramPuzzleRow: Decodable {
    let id: String
    let date: String
    let puzzleNumber: Int
    let schemaVersion: Int
    let puzzleData: Payload

    struct Payload: Decodable {
        let answer: String
        let acceptedAnswers: [String]
        let initialScramble: String
    }

    enum CodingKeys: String, CodingKey {
        case id, date
        case puzzleNumber = "puzzle_number"
        case schemaVersion = "schema_version"
        case puzzleData = "puzzle_data"
    }

    var puzzle: AnagramPuzzle {
        AnagramPuzzle(
            id: id, date: date, puzzleNumber: puzzleNumber,
            schemaVersion: schemaVersion, answer: puzzleData.answer,
            acceptedAnswers: puzzleData.acceptedAnswers,
            initialScramble: puzzleData.initialScramble
        )
    }
}
