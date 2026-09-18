import Foundation

struct BackwordWord: Codable, Identifiable, Equatable {
    var id: String
    let date: String
    /// Immutable issue number supplied by `backword_words.puzzle_number`.
    /// Optional while an older local cache is refreshed.
    let puzzleNumber: Int?
    let word: String  // Always 6 uppercase letters
    let clue: String  // Abstract association hint, e.g. "PATIENCE" for "WAITED"

    init(
        id: String,
        date: String,
        puzzleNumber: Int? = nil,
        word: String,
        clue: String
    ) {
        self.id = id
        self.date = date
        self.puzzleNumber = puzzleNumber
        self.word = word
        self.clue = clue
    }

    enum CodingKeys: String, CodingKey {
        case id, date, puzzleNumber, word, clue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        puzzleNumber = try container.decodeIfPresent(Int.self, forKey: .puzzleNumber)
        word = try container.decode(String.self, forKey: .word)
        clue = try container.decode(String.self, forKey: .clue)
    }
}

// MARK: - Supabase Response Model

// This represents the entire row in your Supabase table
struct BackwordRow: Decodable {
    let id: String
    let date: String
    let puzzleNumber: Int?
    let wordData: WordDataPayload

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case puzzleNumber = "puzzle_number"
        case wordData = "word_data"
    }

    var toBackwordWord: BackwordWord {
        BackwordWord(
            id: id,
            date: date,
            puzzleNumber: puzzleNumber,
            word: wordData.word,
            clue: wordData.clue ?? wordData.category ?? ""
        )
    }
}

struct WordDataPayload: Decodable {
    let word: String
    let reject: Bool
    let clue: String?      // new records
    let category: String?  // old records — fallback
    let definition: String? // old records — ignored
}
