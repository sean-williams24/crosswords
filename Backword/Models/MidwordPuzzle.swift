import Foundation

struct MidwordPuzzle: Codable, Identifiable, Equatable {
    let id: String
    let date: String
    let puzzleNumber: Int
    let firstWord: String
    let secondWord: String
    let answer: String
    let alternatives: [String]

    var firstCompound: String { firstWord + answer }
    var secondCompound: String { answer + secondWord }

    var isValid: Bool {
        let words = [firstWord, secondWord, answer] + alternatives
        return !id.isEmpty && puzzleNumber > 0
            && date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
            && (3...6).contains(answer.count)
            && words.allSatisfy { word in
                !word.isEmpty && word.utf8.allSatisfy { (65...90).contains($0) }
            }
            && alternatives.allSatisfy { $0.count == answer.count && $0 != answer }
    }

    func accepts(_ guess: String) -> Bool {
        guess == answer || alternatives.contains(guess)
    }
}

struct MidwordRow: Decodable {
    let id: String
    let date: String
    let puzzleNumber: Int
    let firstWord: String
    let secondWord: String
    let answer: String
    let alternatives: [String]

    enum CodingKeys: String, CodingKey {
        case id, date, answer, alternatives
        case puzzleNumber = "puzzle_number"
        case firstWord = "first_word"
        case secondWord = "second_word"
    }

    var puzzle: MidwordPuzzle {
        MidwordPuzzle(id: id, date: date, puzzleNumber: puzzleNumber,
                      firstWord: firstWord, secondWord: secondWord,
                      answer: answer, alternatives: alternatives)
    }
}
