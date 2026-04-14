import Foundation

struct WordOfTheDay: Codable, Identifiable {
    var id: String { word }
    let word: String
    let pronunciation: String
    let partOfSpeech: String
    let definition: String
    let etymology: String
    let synonyms: [String]
    let exampleSentence: String
}
