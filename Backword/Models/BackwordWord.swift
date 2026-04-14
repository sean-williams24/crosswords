import Foundation

struct BackwordWord: Codable, Identifiable {
    var id: String { date }
    let date: String
    let word: String       // Always 6 uppercase letters
    let category: String   // e.g. "Animal", "Food", "Nature"
    let definition: String // Revealed as optional hint
}
