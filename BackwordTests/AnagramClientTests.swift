import Foundation
import Testing
@testable import Backword

@MainActor
private final class FakeAnagramSource: AnagramDataSource {
    var puzzle: AnagramPuzzle?
    var shouldFail = false
    var dailyRequests = 0

    func firstPublishedPuzzle() async throws -> AnagramPuzzle? {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return puzzle
    }

    func puzzle(for date: String) async throws -> AnagramPuzzle? {
        dailyRequests += 1
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return puzzle
    }

    func puzzles(for month: ArchiveMonth, through date: String) async throws -> [AnagramPuzzle] {
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return puzzle.map { [$0] } ?? []
    }
}

@Suite("Anagram clients")
struct AnagramClientTests {
    @Test @MainActor func serviceUsesCacheOfflineAndRetries() async {
        let previousRelease = UserDefaults.standard.string(forKey: "Anagram.firstReleaseDate")
        defer {
            if let previousRelease {
                UserDefaults.standard.set(previousRelease, forKey: "Anagram.firstReleaseDate")
            } else {
                UserDefaults.standard.removeObject(forKey: "Anagram.firstReleaseDate")
            }
        }
        let now = Date()
        let date = AnagramProgress.localDay(now)
        let puzzle = AnagramPuzzle(
            id: UUID().uuidString, date: date, puzzleNumber: 1,
            schemaVersion: 1, answer: "TRIANGLE",
            acceptedAnswers: ["INTEGRAL"], initialScramble: "RAGTLINE"
        )
        let source = FakeAnagramSource()
        source.puzzle = puzzle
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: cache) }
        let online = AnagramService(dataSource: source, cacheDirectory: cache)
        await online.refreshIfNeeded(now: now)
        #expect(online.todaysPuzzle == puzzle)
        source.shouldFail = true
        let offline = AnagramService(dataSource: source, cacheDirectory: cache)
        await offline.refreshIfNeeded(now: now)
        #expect(offline.todaysPuzzle == puzzle)
        source.shouldFail = false
        await offline.refreshIfNeeded(now: now)
        #expect(offline.todaysPuzzle == puzzle)
        #expect(source.dailyRequests == 2)
    }

    @Test @MainActor func serviceDoesNotSubstituteReviewPuzzleWhenTodayIsUnavailable() async {
        let source = FakeAnagramSource()
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: cache) }

        let service = AnagramService(dataSource: source, cacheDirectory: cache)
        await service.refreshIfNeeded(now: Date())

        #expect(service.todaysPuzzle == nil)
        #expect(source.dailyRequests == 1)
    }

    @Test @MainActor func viewModelStartsAndRestoresUndo() {
        let puzzle = AnagramPuzzle(
            id: UUID().uuidString, date: "2026-10-01", puzzleNumber: 1,
            schemaVersion: 1, answer: "TRIANGLE",
            acceptedAnswers: ["INTEGRAL"], initialScramble: "RAGTLINE"
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fresh = AnagramViewModel(puzzle: puzzle, persistsChanges: false)
        #expect(fresh.canStart)
        fresh.start(now: now)
        fresh.place(0, now: now.addingTimeInterval(2))
        fresh.place(1, now: now.addingTimeInterval(3))
        let restored = AnagramViewModel(
            puzzle: puzzle, initialProgress: fresh.progress, persistsChanges: false
        )
        #expect(restored.progress?.placementHistory == [0, 1])
        restored.undo(now: now.addingTimeInterval(4))
        #expect(restored.progress?.placementHistory == [0])
        #expect(restored.progress?.startedAt == now)
        restored.reload()
        #expect(restored.progress?.placementHistory == [0])
    }
}
