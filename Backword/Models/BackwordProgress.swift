import Foundation

struct BackwordProgress: Codable {
    let date: String
    var guesses: [String]
    var completedAt: Date?
    var clueRevealed: Bool
    /// Set to true by BackwordViewModel when the winning guess is submitted.
    var wonFlag: Bool

    enum CodingKeys: String, CodingKey {
        case date, guesses, completedAt, wonFlag
        case clueRevealed = "categoryHintUsed"
    }

    init(date: String) {
        self.date = date
        self.guesses = []
        self.completedAt = nil
        self.clueRevealed = false
        self.wonFlag = false
    }

    // MARK: - Computed

    /// Letters revealed so far. Starts at 1 (last letter only), +1 per wrong guess, max 6.
    var revealedCount: Int { min(guesses.count + 1, 6) }

    var isWon: Bool { wonFlag && completedAt != nil }
    var isFailed: Bool { !wonFlag && completedAt != nil }
    var isComplete: Bool { completedAt != nil }
    var completedScore: Int? {
        guard isComplete else { return nil }
        return isWon ? Int.backwordScore(guessCount: guesses.count) : 0
    }
}

// MARK: - Persistence

extension BackwordProgress {
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backword", isDirectory: true)
    }

    private static func fileURL(for date: String) -> URL {
        directory.appendingPathComponent("backword_\(date).json")
    }

    func save() {
        let dir = Self.directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: Self.fileURL(for: date), options: .atomic)
        }
    }

    static func load(date: String) -> BackwordProgress? {
        guard let data = try? Data(contentsOf: fileURL(for: date)) else { return nil }
        return try? JSONDecoder().decode(BackwordProgress.self, from: data)
    }

    static func delete(date: String) {
        try? FileManager.default.removeItem(at: fileURL(for: date))
    }

    static func loadAll() -> [BackwordProgress] {
        let dir = directory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files
            .filter { $0.lastPathComponent.hasPrefix("backword_") && $0.pathExtension == "json" }
            .compactMap { url -> BackwordProgress? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(BackwordProgress.self, from: data)
            }
            .sorted { $0.date > $1.date }
    }
}
