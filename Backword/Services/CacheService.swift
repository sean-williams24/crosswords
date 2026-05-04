import Foundation

final class CacheService {

    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
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

    private func ensureDirectory() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
}
