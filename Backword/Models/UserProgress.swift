import Foundation

/// Guest records retain the app's original location. Signed-in records live
/// under a user UUID so signing out never exposes another account's cache.
enum ProgressStorageNamespace {
    private static let accountIDKey = "backword_progress_account_id"
    private static let guestMigrationAccountIDKey = "backword_guest_migration_account_id"

    static var accountID: String? {
        UserDefaults.standard.string(forKey: accountIDKey)
    }

    static func activate(accountID: String?) {
        if let accountID {
            UserDefaults.standard.set(accountID, forKey: accountIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: accountIDKey)
        }
    }

    /// Claims the current guest namespace before it is copied to cloud data.
    /// A failed upload intentionally retains this owner, so switching accounts
    /// cannot copy the same on-device guest records into a second account.
    static func claimGuestMigration(for accountID: String) -> Bool {
        if let owner = UserDefaults.standard.string(forKey: guestMigrationAccountIDKey) {
            return owner == accountID
        }
        UserDefaults.standard.set(accountID, forKey: guestMigrationAccountIDKey)
        return true
    }

    /// Once every guest record has been removed after a successful migration,
    /// a later, genuinely new guest session may be claimed by another account.
    static func clearGuestMigrationClaim() {
        UserDefaults.standard.removeObject(forKey: guestMigrationAccountIDKey)
    }

    static func directory(base: URL) -> URL {
        guard let accountID else { return base }
        return base
            .appendingPathComponent("users", isDirectory: true)
            .appendingPathComponent(accountID, isDirectory: true)
    }
}

struct UserProgress: Codable {
    let puzzleId: String
    var entries: [[String?]]
    var completedClueIds: Set<Int>
    var hintedClueIds: Set<Int>
    var hintsUsed: Int
    var startedAt: Date
    var completedAt: Date?
    var puzzleDate: String?   // "yyyy-MM-dd" — added for rating backfill
    var totalClues: Int?      // total clue count — added for rating backfill
    var isWeekly: Bool?       // true if weekly puzzle — added for rating backfill
    var gaveUpAt: Date?
    var gaveUpScore: Int?
    var gaveUpRevealedCells: Set<String>
    /// The score legitimately earned during this puzzle's original release
    /// window. Archive progress must never change this snapshot.
    var releaseDateScore: Int
    /// Persisted cross-device conflict tie-breaker. Local saves refresh it.
    var updatedAt: Date

    var isComplete: Bool { completedAt != nil }

    init(puzzleId: String, size: Int, puzzleDate: String? = nil, totalClues: Int? = nil, isWeekly: Bool? = nil) {
        self.puzzleId = puzzleId
        self.entries = Array(repeating: Array(repeating: nil, count: size), count: size)
        self.completedClueIds = []
        self.hintedClueIds = []
        self.hintsUsed = 0
        self.startedAt = Date()
        self.completedAt = nil
        self.puzzleDate = puzzleDate
        self.totalClues = totalClues
        self.isWeekly = isWeekly
        self.gaveUpAt = nil
        self.gaveUpScore = nil
        self.gaveUpRevealedCells = []
        self.releaseDateScore = 0
        self.updatedAt = Date()
    }

    init(
        puzzleId: String,
        entries: [[String?]],
        completedClueIds: Set<Int>,
        hintedClueIds: Set<Int>,
        hintsUsed: Int,
        startedAt: Date,
        completedAt: Date?,
        puzzleDate: String?,
        totalClues: Int?,
        isWeekly: Bool?,
        gaveUpAt: Date?,
        gaveUpScore: Int?,
        gaveUpRevealedCells: Set<String>,
        releaseDateScore: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.puzzleId = puzzleId
        self.entries = entries
        self.completedClueIds = completedClueIds
        self.hintedClueIds = hintedClueIds
        self.hintsUsed = hintsUsed
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.puzzleDate = puzzleDate
        self.totalClues = totalClues
        self.isWeekly = isWeekly
        self.gaveUpAt = gaveUpAt
        self.gaveUpScore = gaveUpScore
        self.gaveUpRevealedCells = gaveUpRevealedCells
        self.releaseDateScore = releaseDateScore
        self.updatedAt = updatedAt
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
        puzzleDate = try container.decodeIfPresent(String.self, forKey: .puzzleDate)
        totalClues = try container.decodeIfPresent(Int.self, forKey: .totalClues)
        isWeekly = try container.decodeIfPresent(Bool.self, forKey: .isWeekly)
        gaveUpAt = try container.decodeIfPresent(Date.self, forKey: .gaveUpAt)
        gaveUpScore = try container.decodeIfPresent(Int.self, forKey: .gaveUpScore)
        gaveUpRevealedCells = try container.decodeIfPresent(Set<String>.self, forKey: .gaveUpRevealedCells) ?? []
        releaseDateScore = try container.decodeIfPresent(Int.self, forKey: .releaseDateScore) ?? 0
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? completedAt ?? startedAt
    }

    var elapsedTime: TimeInterval {
        let end = completedAt ?? Date()
        return end.timeIntervalSince(startedAt)
    }

    var formattedTime: String {
        Int(elapsedTime).formattedTimeHHMMSS
    }
}

// MARK: - Persistence

extension UserProgress {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backword", isDirectory: true)
        return ProgressStorageNamespace.directory(base: base)
    }

    private static func fileURL(for puzzleId: String) -> URL {
        directory.appendingPathComponent("progress_\(puzzleId).json")
    }

    func save() {
        let dir = Self.directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var progress = self
        progress.updatedAt = Date()
        if let data = try? JSONEncoder().encode(progress) {
            try? data.write(to: Self.fileURL(for: puzzleId), options: .atomic)
        }
        Task { @MainActor in
            ProgressCloudSync.shared.scheduleUpload(progress)
        }
    }

    static func load(puzzleId: String) -> UserProgress? {
        guard let data = try? Data(contentsOf: fileURL(for: puzzleId)) else { return nil }
        return try? JSONDecoder().decode(UserProgress.self, from: data)
    }

    static func delete(puzzleId: String) {
        try? FileManager.default.removeItem(at: fileURL(for: puzzleId))
    }

    /// Load all progress files from disk.
    static func loadAll() -> [UserProgress] {
        let dir = directory
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.compactMap { url -> UserProgress? in
            guard url.lastPathComponent.hasPrefix("progress_"),
                  url.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(UserProgress.self, from: data)
        }
    }
}
