import Foundation

struct MidwordProgress: Codable, Equatable {
    let date: String
    var guesses: [String] = []
    var completedAt: Date?
    var won = false
    var releaseDateScore = 0
    var updatedAt = Date()

    var isComplete: Bool { completedAt != nil }
    var isWon: Bool { isComplete && won }
    var isFailed: Bool { isComplete && !won }

    init(date: String) { self.date = date }

    enum CodingKeys: String, CodingKey {
        case date, guesses, completedAt, won, releaseDateScore, updatedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try values.decode(String.self, forKey: .date)
        guesses = try values.decodeIfPresent([String].self, forKey: .guesses) ?? []
        completedAt = try values.decodeIfPresent(Date.self, forKey: .completedAt)
        won = try values.decodeIfPresent(Bool.self, forKey: .won) ?? false
        releaseDateScore = try values.decodeIfPresent(Int.self, forKey: .releaseDateScore) ?? 0
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? completedAt ?? Date()
    }

    mutating func submit(_ guess: String, for puzzle: MidwordPuzzle, at now: Date = Date()) {
        guard !isComplete, guesses.count < 5, guess.count == puzzle.answer.count else { return }
        guesses.append(guess)
        updatedAt = now
        won = puzzle.accepts(guess)
        if won || guesses.count == 5 {
            completedAt = now
            if won && ContentReleaseCalendar(now: now).dailyDateString == puzzle.date {
                releaseDateScore = max(0, 6 - guesses.count)
            }
        }
    }
}

extension MidwordProgress {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backword", isDirectory: true)
        return ProgressStorageNamespace.directory(base: base)
    }

    private static func fileURL(for date: String) -> URL {
        directory.appendingPathComponent("midword_\(date).json")
    }

    func save() {
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        var saved = self
        saved.updatedAt = Date()
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: Self.fileURL(for: date), options: .atomic)
        NotificationCenter.default.post(name: .midwordProgressDidChange, object: nil)
        Task { @MainActor in ProgressCloudSync.shared.scheduleUpload(saved) }
    }

    static func load(date: String) -> Self? {
        guard let data = try? Data(contentsOf: fileURL(for: date)) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func loadAll() -> [Self] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.lastPathComponent.hasPrefix("midword_") && $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Self.self, from: Data(contentsOf: $0)) }
            .sorted { $0.date > $1.date }
    }

    static func delete(date: String) {
        try? FileManager.default.removeItem(at: fileURL(for: date))
        NotificationCenter.default.post(name: .midwordProgressDidChange, object: nil)
    }
}

extension Notification.Name {
    static let midwordProgressDidChange = Notification.Name("midwordProgressDidChange")
}
