import Foundation

struct BackwordWord: Codable, Identifiable, Equatable {
    var id: String
    let date: String
    let word: String  // Always 6 uppercase letters
    let clue: String  // Abstract association hint, e.g. "PATIENCE" for "WAITED"
}

// MARK: - Supabase Response Model

// This represents the entire row in your Supabase table
struct BackwordRow: Decodable {
    let id: String
    let date: String
    let wordData: WordDataPayload

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case wordData = "word_data"
    }

    var toBackwordWord: BackwordWord {
        BackwordWord(
            id: id,
            date: date,
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
