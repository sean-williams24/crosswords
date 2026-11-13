import Foundation

struct MidwordProgress: Codable, Equatable {
    let date: String
    var guesses: [String] = []
    var startedAt: Date?
    var elapsedSecondsAtCompletion: Int?
    var completedAt: Date?
    var won = false
    var releaseDateScore = 0
    var updatedAt = Date()

    var isComplete: Bool { completedAt != nil }
    var isWon: Bool { isComplete && won }
    var isFailed: Bool { isComplete && !won }
    var isGaveUp: Bool { isFailed && (startedAt != nil || guesses.count < 5) }

    init(date: String) { self.date = date }

    enum CodingKeys: String, CodingKey {
        case date, guesses, startedAt, elapsedSecondsAtCompletion, completedAt, won, releaseDateScore, updatedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try values.decode(String.self, forKey: .date)
        guesses = try values.decodeIfPresent([String].self, forKey: .guesses) ?? []
        startedAt = try values.decodeIfPresent(Date.self, forKey: .startedAt)
        elapsedSecondsAtCompletion = try values.decodeIfPresent(Int.self, forKey: .elapsedSecondsAtCompletion)
        completedAt = try values.decodeIfPresent(Date.self, forKey: .completedAt)
        won = try values.decodeIfPresent(Bool.self, forKey: .won) ?? false
        releaseDateScore = try values.decodeIfPresent(Int.self, forKey: .releaseDateScore) ?? 0
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt) ?? completedAt ?? Date()
    }

    mutating func start(at now: Date = Date()) {
        guard !isComplete, startedAt == nil else { return }
        startedAt = now
        updatedAt = now
    }

    func elapsedSeconds(at now: Date = Date()) -> Int {
        elapsedSecondsAtCompletion ?? startedAt.map { max(0, Int(now.timeIntervalSince($0))) } ?? 0
    }

    static func points(for seconds: Int) -> Int {
        switch seconds {
        case ..<30: return 5
        case ..<60: return 4
        case ..<120: return 3
        case ..<180: return 2
        default: return 1
        }
    }

    var formattedCompletionTime: String {
        Self.formatTime(elapsedSecondsAtCompletion)
    }

    static func formatTime(_ seconds: Int?) -> String {
        guard let seconds else { return "–" }
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }

    /// Legacy terminal results are immutable. Timed attempts retain the earliest
    /// start and first terminal outcome; guesses remain one whole record.
    static func merged(_ a: Self, _ b: Self) -> Self {
        let earliestStart = [a.startedAt, b.startedAt].compactMap { $0 }.min()
        let legacy = [a, b].filter {
            $0.isComplete && $0.startedAt == nil && (earliestStart == nil || $0.completedAt! <= earliestStart!)
        }
        if let saved = legacy.max(by: { $0.releaseDateScore < $1.releaseDateScore }) { return saved }
        let candidates = [a, b].filter { earliestStart == nil || $0.startedAt != nil }
        let terminal = candidates.filter(\.isComplete)
        var winner = terminal.min(by: { $0.completedAt! < $1.completedAt! })
            ?? (candidates.max(by: {
                if ($0.startedAt != nil) != ($1.startedAt != nil) { return $0.startedAt == nil }
                if $0.guesses.count != $1.guesses.count { return $0.guesses.count < $1.guesses.count }
                return $0.updatedAt < $1.updatedAt
            })!)
        winner.startedAt = earliestStart
        if let completed = winner.completedAt, let start = winner.startedAt {
            winner.elapsedSecondsAtCompletion = max(0, Int(completed.timeIntervalSince(start)))
            winner.releaseDateScore = winner.isWon && winner.releaseDateScore > 0
                ? points(for: winner.elapsedSecondsAtCompletion!) : 0
        }
        return winner
    }

    mutating func giveUp(at now: Date = Date()) {
        guard !isComplete, startedAt != nil else { return }
        elapsedSecondsAtCompletion = startedAt.map { _ in elapsedSeconds(at: now) }
        completedAt = now
        updatedAt = now
        won = false
        releaseDateScore = 0
    }

    mutating func submit(_ guess: String, for puzzle: MidwordPuzzle, at now: Date = Date()) {
        guard !isComplete, startedAt != nil, guess.count == puzzle.answer.count else { return }
        guesses.append(guess)
        updatedAt = now
        won = puzzle.accepts(guess)
        if won {
            elapsedSecondsAtCompletion = elapsedSeconds(at: now)
            completedAt = now
            if won && ContentReleaseCalendar(now: now).dailyDateString == puzzle.date {
                releaseDateScore = Self.points(for: elapsedSecondsAtCompletion ?? 0)
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
