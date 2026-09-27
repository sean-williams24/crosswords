import Foundation

struct AnagramProgress: Codable, Equatable {
    enum Outcome: String, Codable { case solved, gaveUp = "gave_up" }
    enum HintSource: String, Codable { case rewardedAd = "rewarded_ad", timePenalty = "time_penalty" }

    var schemaVersion = 1
    let puzzleID: String
    let date: String
    private(set) var startedAt: Date
    var trayOrder: [Int]
    var placedTileIDs: [Int?]
    var placementHistory: [Int] = []
    var hintUsed = false
    var hintSource: HintSource?
    var penaltySeconds = 0
    var lockedCellIndex: Int?
    var lockedTileID: Int?
    var outcome: Outcome?
    var completedAt: Date?
    var elapsedSecondsAtCompletion: Int?
    var releaseDateScore = 0
    var updatedAt: Date

    init(puzzle: AnagramPuzzle, now: Date = Date()) {
        puzzleID = puzzle.id
        date = puzzle.date
        startedAt = now
        updatedAt = now
        trayOrder = Array(0..<puzzle.length)
        placedTileIDs = Array(repeating: nil, count: puzzle.length)
    }

    init(
        puzzleID: String, date: String, startedAt: Date, trayOrder: [Int],
        placedTileIDs: [Int?], placementHistory: [Int], hintUsed: Bool,
        hintSource: HintSource?, penaltySeconds: Int, lockedCellIndex: Int?,
        lockedTileID: Int?, outcome: Outcome?, completedAt: Date?,
        elapsedSecondsAtCompletion: Int?, releaseDateScore: Int, updatedAt: Date
    ) {
        self.puzzleID = puzzleID
        self.date = date
        self.startedAt = startedAt
        self.trayOrder = trayOrder
        self.placedTileIDs = placedTileIDs
        self.placementHistory = placementHistory
        self.hintUsed = hintUsed
        self.hintSource = hintSource
        self.penaltySeconds = penaltySeconds
        self.lockedCellIndex = lockedCellIndex
        self.lockedTileID = lockedTileID
        self.outcome = outcome
        self.completedAt = completedAt
        self.elapsedSecondsAtCompletion = elapsedSecondsAtCompletion
        self.releaseDateScore = releaseDateScore
        self.updatedAt = updatedAt
    }

    var isComplete: Bool { outcome != nil }
    var canUndo: Bool { !isComplete && !placementHistory.isEmpty }
    var canRestart: Bool { canUndo }
    var availableTileIDs: [Int] { trayOrder.filter { !placedTileIDs.contains($0) } }

    func isValid(for puzzle: AnagramPuzzle) -> Bool {
        guard schemaVersion == 1, puzzleID == puzzle.id, date == puzzle.date,
              trayOrder.sorted() == Array(0..<puzzle.length),
              placedTileIDs.count == puzzle.length else { return false }
        let placed = placedTileIDs.compactMap { $0 }
        guard Set(placed).count == placed.count,
              placed.allSatisfy({ (0..<puzzle.length).contains($0) }),
              Set(placementHistory).count == placementHistory.count,
              placementHistory.allSatisfy({ placed.contains($0) }),
              Set(placementHistory) == Set(placed.filter { $0 != lockedTileID }) else { return false }
        guard (outcome == nil) == (completedAt == nil), (0...5).contains(releaseDateScore),
              penaltySeconds >= 0 else { return false }
        if !hintUsed {
            guard hintSource == nil, lockedCellIndex == nil, lockedTileID == nil,
                  penaltySeconds == 0 else { return false }
        } else if hintSource == nil {
            return false
        }
        if hintUsed && !isComplete {
            guard let lockedCellIndex, let lockedTileID,
                  placedTileIDs.indices.contains(lockedCellIndex),
                  placedTileIDs[lockedCellIndex] == lockedTileID else { return false }
        }
        return true
    }

    func displayedAnswer(for puzzle: AnagramPuzzle) -> String? {
        guard placedTileIDs.allSatisfy({ $0 != nil }) else { return nil }
        let letters = Array(puzzle.initialScramble)
        return String(placedTileIDs.compactMap { $0.map { letters[$0] } })
    }

    mutating func place(_ tileID: Int, in puzzle: AnagramPuzzle, now: Date = Date()) {
        guard !isComplete, availableTileIDs.contains(tileID),
              let cell = placedTileIDs.firstIndex(where: { $0 == nil }) else { return }
        placedTileIDs[cell] = tileID
        placementHistory.append(tileID)
        updatedAt = now
        if let answer = displayedAnswer(for: puzzle), puzzle.answers.contains(answer) {
            finish(.solved, now: now)
        }
    }

    mutating func undo(now: Date = Date()) {
        guard canUndo, let tile = placementHistory.popLast(),
              let cell = placedTileIDs.firstIndex(of: tile) else { return }
        placedTileIDs[cell] = nil
        updatedAt = now
    }

    mutating func restart(now: Date = Date()) {
        guard canRestart else { return }
        for tile in placementHistory {
            if let cell = placedTileIDs.firstIndex(of: tile) { placedTileIDs[cell] = nil }
        }
        placementHistory.removeAll()
        updatedAt = now
    }

    mutating func shuffle(using order: [Int], now: Date = Date()) {
        guard !isComplete else { return }
        let available = availableTileIDs
        guard order.sorted() == available.sorted() else { return }
        var iterator = order.makeIterator()
        trayOrder = trayOrder.map { available.contains($0) ? iterator.next()! : $0 }
        updatedAt = now
    }

    mutating func revealHint(in puzzle: AnagramPuzzle, source: HintSource, now: Date = Date()) {
        guard !hintUsed, !isComplete else { return }
        restart(now: now)
        guard let target = placedTileIDs.firstIndex(where: { $0 == nil }),
              let tile = availableTileIDs.first(where: { Array(puzzle.initialScramble)[$0] == Array(puzzle.answer)[target] })
        else { return }
        placedTileIDs[target] = tile
        lockedCellIndex = target
        lockedTileID = tile
        hintUsed = true
        hintSource = source
        penaltySeconds = source == .timePenalty ? 30 : 0
        updatedAt = now
    }

    mutating func giveUp(now: Date = Date()) {
        guard !isComplete else { return }
        finish(.gaveUp, now: now)
    }

    mutating func finish(_ result: Outcome, now: Date) {
        outcome = result
        completedAt = now
        elapsedSecondsAtCompletion = max(0, Int(now.timeIntervalSince(startedAt)))
        releaseDateScore = result == .solved && Self.localDay(now) == date
            ? Self.points(for: (elapsedSecondsAtCompletion ?? 0) + penaltySeconds) : 0
        updatedAt = now
    }

    func elapsedSeconds(at now: Date = Date()) -> Int {
        elapsedSecondsAtCompletion ?? max(0, Int(now.timeIntervalSince(startedAt)))
    }

    static func points(for seconds: Int) -> Int {
        switch seconds {
        case ..<30: 5
        case ..<60: 4
        case ..<120: 3
        case ..<180: 2
        default: 1
        }
    }

    static func localDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    /// A remote arrangement and its Undo history always travel together.
    static func merged(_ a: Self, _ b: Self) -> Self {
        var winner: Self
        if a.isComplete != b.isComplete {
            winner = a.isComplete ? a : b
        } else if a.isComplete, b.isComplete {
            winner = (a.completedAt ?? .distantFuture) <= (b.completedAt ?? .distantFuture) ? a : b
        } else if a.hintUsed != b.hintUsed {
            winner = a.hintUsed ? a : b
        } else if a.placementHistory.count != b.placementHistory.count {
            winner = a.placementHistory.count > b.placementHistory.count ? a : b
        } else {
            winner = a.updatedAt >= b.updatedAt ? a : b
        }
        winner.startedAt = min(a.startedAt, b.startedAt)
        winner.hintUsed = a.hintUsed || b.hintUsed
        winner.hintSource = winner.hintSource ?? a.hintSource ?? b.hintSource
        winner.penaltySeconds = max(a.penaltySeconds, b.penaltySeconds)
        winner.releaseDateScore = max(a.releaseDateScore, b.releaseDateScore)
        if let completed = winner.completedAt {
            winner.elapsedSecondsAtCompletion = max(0, Int(completed.timeIntervalSince(winner.startedAt)))
            if winner.outcome == .solved, Self.localDay(completed) == winner.date {
                winner.releaseDateScore = Self.points(for: (winner.elapsedSecondsAtCompletion ?? 0) + winner.penaltySeconds)
            } else {
                winner.releaseDateScore = 0
            }
        }
        return winner
    }
}

extension AnagramProgress {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backword", isDirectory: true)
        return ProgressStorageNamespace.directory(base: base).appendingPathComponent("anagram", isDirectory: true)
    }

    func save() {
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.directory.appendingPathComponent("\(date).json"), options: .atomic)
    }

    static func load(date: String) -> Self? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("\(date).json")) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func loadAll() -> [Self] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { url in
            guard url.lastPathComponent != "review.json" else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Self.self, from: data)
        }
    }

    static func delete(date: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(date).json"))
    }
}

struct AnagramHomeCardSummary {
    enum Status: Equatable {
        case new
        case inProgress
        case solved
        case finished
        case gaveUp
    }

    let status: Status
    let score: Int?
    let streak: Int

    init(
        progress: AnagramProgress?, history: [AnagramProgress],
        now: Date = Date(), calendar: Calendar = .current
    ) {
        switch progress?.outcome {
        case .none:
            status = progress == nil ? .new : .inProgress
        case .some(.solved):
            status = (progress?.releaseDateScore ?? 0) > 0 ? .solved : .finished
        case .some(.gaveUp):
            status = .gaveUp
        }
        if progress?.isComplete == true, let progress {
            score = progress.releaseDateScore
        } else {
            score = nil
        }
        streak = Self.currentStreak(in: history, now: now, calendar: calendar)
    }

    private static func currentStreak(in history: [AnagramProgress], now: Date, calendar: Calendar) -> Int {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let records = Dictionary(history.filter { $0.date != "review" }.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
        let today = calendar.startOfDay(for: now)
        let todaysRecord = records[formatter.string(from: today)]
        if todaysRecord?.isComplete == true, todaysRecord?.releaseDateScore == 0 { return 0 }

        var day = (todaysRecord?.releaseDateScore ?? 0) > 0
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today)!
        var streak = 0
        while let record = records[formatter.string(from: day)],
              record.outcome == .solved, record.releaseDateScore > 0 {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }
        return streak
    }
}
