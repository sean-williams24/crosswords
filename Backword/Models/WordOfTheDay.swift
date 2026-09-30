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

    var partOfSpeechExplanation: String? {
        switch partOfSpeech.lowercased() {
        case "noun":
            return "Noun: a word that names a person, place, thing, or idea."
        case "verb":
            return "Verb: a word that describes an action, state, or occurrence."
        case "adjective":
            return "Adjective: a describing word that modifies a noun."
        case "adverb":
            return "Adverb: a word that modifies a verb, adjective, or other adverb — often ending in -ly."
        case "pronoun":
            return "Pronoun: a word used in place of a noun, such as he, she, or it."
        case "preposition":
            return "Preposition: a word that shows the relationship between a noun and other words, such as in, on, or at."
        case "conjunction":
            return "Conjunction: a word that connects words, phrases, or clauses — such as and, but, or or."
        case "interjection":
            return "Interjection: a word or phrase that expresses strong emotion, such as oh! or wow!"
        default:
            return nil
        }
    }
}
