import Foundation

struct UserProgress: Codable {
    let puzzleId: String
    var entries: [[String?]]
    var completedClueIds: Set<Int>
    var hintedClueIds: Set<Int>
    var hintsUsed: Int
    var startedAt: Date
    var completedAt: Date?

    var isComplete: Bool { completedAt != nil }

    init(puzzleId: String, size: Int) {
        self.puzzleId = puzzleId
        self.entries = Array(repeating: Array(repeating: nil, count: size), count: size)
        self.completedClueIds = []
        self.hintedClueIds = []
        self.hintsUsed = 0
        self.startedAt = Date()
        self.completedAt = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        puzzleId = try container.decode(String.self, forKey: .puzzleId)
        entries = try container.decode([[String?]].self, forKey: .entries)
        completedClueIds = try container.decode(Set<Int>.self, forKey: .completedClueIds)
        hintedClueIds = try container.decodeIfPresent(Set<Int>.self, forKey: .hintedClueIds) ?? []
        hintsUsed = try container.decode(Int.self, forKey: .hintsUsed)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    var elapsedTime: TimeInterval {
        let end = completedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }

    var formattedTime: String {
        let seconds = Int(elapsedTime)
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Persistence

extension UserProgress {
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backword", isDirectory: true)
    }

    private static func fileURL(for puzzleId: String) -> URL {
        directory.appendingPathComponent("progress_\(puzzleId).json")
    }

    func save() {
        let dir = Self.directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: Self.fileURL(for: puzzleId), options: .atomic)
        }
    }

    static func load(puzzleId: String) -> UserProgress? {
        guard let data = try? Data(contentsOf: fileURL(for: puzzleId)) else { return nil }
        return try? JSONDecoder().decode(UserProgress.self, from: data)
    }
}
