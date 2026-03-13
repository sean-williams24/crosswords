import Foundation

@MainActor
final class WOTDService: ObservableObject {

    @Published var todaysWord: WordOfTheDay?

    private let words: [WordOfTheDay]

    init() {
        words = Self.loadWords()
        todaysWord = wordForToday()
    }

    private func wordForToday() -> WordOfTheDay? {
        guard !words.isEmpty else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        let dayHash = (components.year ?? 0) * 10000 + (components.month ?? 0) * 100 + (components.day ?? 0)
        return words[abs(dayHash) % words.count]
    }

    private static func loadWords() -> [WordOfTheDay] {
        guard let url = Bundle.main.url(forResource: "wotd_bank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let words = try? JSONDecoder().decode([WordOfTheDay].self, from: data)
        else { return [] }
        return words
    }
}
