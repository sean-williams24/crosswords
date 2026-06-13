import Foundation

final class CacheService {

    private let fileManager = FileManager.default
    private let customCacheDirectory: URL?

    init(cacheDirectory: URL? = nil) {
        self.customCacheDirectory = cacheDirectory
    }

    private var cacheDirectory: URL {
        customCacheDirectory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backword/Puzzles", isDirectory: true)
    }

    // MARK: - Backword Cache

    func saveBackword(_ backword: BackwordWord, for date: String) {
        ensureDirectory()
        let url = backwordFileURL(for: date)
        if let data = try? JSONEncoder().encode(backword) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func loadBackword(for date: String) -> BackwordWord? {
        let url = backwordFileURL(for: date)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BackwordWord.self, from: data)
    }

    // MARK: - WOTD Cache

    func saveWOTD(_ backword: WordOfTheDay, for date: String) {
        ensureDirectory()
        let url = wotdFileURL(for: date)
        if let data = try? JSONEncoder().encode(backword) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func loadWOTD(for date: String) -> WordOfTheDay? {
        let url = wotdFileURL(for: date)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WordOfTheDay.self, from: data)
    }

    // MARK: - Puzzle Cache

    func savePuzzle(_ puzzle: Puzzle, for date: String) {
        ensureDirectory()
        let url = fileURL(for: date)
        if let data = try? JSONEncoder().encode(puzzle) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func loadPuzzle(for date: String) -> Puzzle? {
        let url = fileURL(for: date)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Puzzle.self, from: data)
    }

    func clearPuzzle(for date: String) {
        try? fileManager.removeItem(at: fileURL(for: date))
    }

    func clearBackword(for date: String) {
        try? fileManager.removeItem(at: backwordFileURL(for: date))
    }

    func clearWOTD(for date: String) {
        try? fileManager.removeItem(at: wotdFileURL(for: date))
    }

    // MARK: - Monthly Archive Cache

    func saveDailyArchive(_ puzzles: [Puzzle], for month: ArchiveMonth) {
        save(puzzles, to: archiveFileURL(prefix: "archive_daily", month: month))
    }

    func loadDailyArchive(for month: ArchiveMonth) -> [Puzzle]? {
        load([Puzzle].self, from: archiveFileURL(prefix: "archive_daily", month: month))
    }

    func saveWeeklyArchive(_ puzzles: [Puzzle], for month: ArchiveMonth) {
        save(puzzles, to: archiveFileURL(prefix: "archive_weekly", month: month))
    }

    func loadWeeklyArchive(for month: ArchiveMonth) -> [Puzzle]? {
        load([Puzzle].self, from: archiveFileURL(prefix: "archive_weekly", month: month))
    }

    func saveBackwordArchive(_ words: [BackwordWord], for month: ArchiveMonth) {
        save(words, to: archiveFileURL(prefix: "archive_backword", month: month))
    }

    func loadBackwordArchive(for month: ArchiveMonth) -> [BackwordWord]? {
        load([BackwordWord].self, from: archiveFileURL(prefix: "archive_backword", month: month))
    }

    func saveArchiveMonths(_ months: [ArchiveMonth], for type: ArchiveGameType) {
        save(months, to: archiveMonthsFileURL(for: type))
    }

    func loadArchiveMonths(for type: ArchiveGameType) -> [ArchiveMonth]? {
        load([ArchiveMonth].self, from: archiveMonthsFileURL(for: type))
    }

    func clearOldPuzzles(olderThan days: Int = 30) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        for url in contents {
            if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
               let created = attrs[.creationDate] as? Date,
               created < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    // MARK: - Private

    private func fileURL(for date: String) -> URL {
        cacheDirectory.appendingPathComponent("puzzle_\(date).json")
    }

    private func backwordFileURL(for date: String) -> URL {
        cacheDirectory.appendingPathComponent("backword_\(date).json")
    }

    private func wotdFileURL(for date: String) -> URL {
        cacheDirectory.appendingPathComponent("wotd\(date).json")
    }

    private func archiveFileURL(prefix: String, month: ArchiveMonth) -> URL {
        cacheDirectory.appendingPathComponent("\(prefix)_\(month.key).json")
    }

    private func archiveMonthsFileURL(for type: ArchiveGameType) -> URL {
        cacheDirectory.appendingPathComponent("archive_months_\(type.rawValue).json")
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        ensureDirectory()
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func ensureDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
}
