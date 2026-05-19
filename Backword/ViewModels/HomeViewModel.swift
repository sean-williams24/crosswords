import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var todaysPuzzle: Puzzle?
    @Published var todaysProgress: UserProgress?
    @Published var weeklyPuzzle: Puzzle?
    @Published var weeklyProgress: UserProgress?
    @Published var isLoading = true
    @Published var crosswordsFetchDidFail: Bool = false
    var isFetching = false
    private let puzzleService: PuzzleService
    #if DEBUG
    var previewMode = false
    #endif

    enum State {
        case loading
        case success
        case failed
    }

    @Published var state: State = .loading

    init(puzzleService: PuzzleService) {
        self.puzzleService = puzzleService
    }

    func refreshIfNeeded(isProUser: Bool) async {
        #if DEBUG
        if previewMode { return }
        #endif
        let today = formattedToday()
        let dailyStale = todaysPuzzle?.date != today
        let weeklyStale = isProUser && weeklyPuzzleIsStale()

        if dailyStale || weeklyStale {
            guard !isFetching else { return }
            await loadTodaysPuzzle()
        } else {
            // Puzzle is still current — just refresh progress from disk in case
            // the user played since we last loaded (e.g. returned from PuzzleView)
            if let puzzle = todaysPuzzle {
                todaysProgress = UserProgress.load(puzzleId: puzzle.id)
            }
            if let weekly = weeklyPuzzle {
                weeklyProgress = UserProgress.load(puzzleId: weekly.id)
            }
        }
    }

    private func weeklyPuzzleIsStale() -> Bool {
        guard let dateString = weeklyPuzzle?.date else { return true }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let puzzleDate = f.date(from: dateString) else { return true }
        let daysSince = Calendar.current.dateComponents([.day], from: puzzleDate, to: Date()).day ?? 0
        return daysSince >= 7
    }

    private func formattedToday() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    func loadTodaysPuzzle() async {
        state = .loading
        do {
            isFetching = true
            let puzzle = try await puzzleService.fetchTodaysPuzzle()
            todaysPuzzle = puzzle
            todaysProgress = UserProgress.load(puzzleId: puzzle.id)
            let weekly = try await puzzleService.fetchCurrentWeeklyPuzzle()
            weeklyPuzzle = weekly
            weeklyProgress = UserProgress.load(puzzleId: weekly.id)
            state = .success
        } catch {
            todaysPuzzle = nil
            weeklyPuzzle = nil
            crosswordsFetchDidFail = true
            state = .failed
        }
        isFetching = false
    }

    var dailyCrosswordScore: Int? {
        guard let progress = todaysProgress,
              let total = progress.totalClues, total > 0,
              progress.completedClueIds.count > 0 else { return nil }
        let pct = Int(Double(progress.completedClueIds.count) / Double(total) * 100)
        return max(0, Int.crosswordScore(percentComplete: pct) - progress.hintsUsed / 3)
    }

    var puzzleStatus: PuzzleStatus {
        guard let progress = todaysProgress else { return .new }
        if progress.isComplete { return .completed(progress.formattedTime) }
        return .inProgress
    }

    var weeklyPuzzleStatus: PuzzleStatus {
        guard let progress = weeklyProgress else { return .new }
        if progress.isComplete { return .completed(progress.formattedTime) }
        return .inProgress
    }
}

// MARK: - Debug helpers

#if DEBUG
extension HomeViewModel {
    /// Fills all clues except the last one, so you're one answer away from completion.
    func debugFillAllButOne(puzzle: Puzzle, isWeekly: Bool) {
        var progress = UserProgress.load(puzzleId: puzzle.id)
            ?? UserProgress(puzzleId: puzzle.id, size: puzzle.size,
                            puzzleDate: puzzle.date, totalClues: puzzle.clues.count, isWeekly: isWeekly)

        let clues = puzzle.clues.dropLast()  // leave the very last clue empty
        for clue in clues {
            let letters = Array(clue.answer)
            for (offset, letter) in letters.enumerated() {
                let row: Int
                let col: Int
                switch clue.direction {
                case .across: row = clue.startRow; col = clue.startCol + offset
                case .down:   row = clue.startRow + offset; col = clue.startCol
                }
                progress.entries[row][col] = String(letter)
            }
            progress.completedClueIds.insert(clue.id)
        }
        progress.save()

        if isWeekly {
            weeklyProgress = progress
        } else {
            todaysProgress = progress
        }
    }

    /// Purges the cached daily puzzle and re-fetches it from Supabase.
    func debugPurgeDailyPuzzle() async {
        puzzleService.purgeDailyCache()
        todaysPuzzle = nil
        todaysProgress = nil
        await loadTodaysPuzzle()
    }

    /// Purges the cached weekly puzzle and re-fetches it from Supabase.
    func debugPurgeWeeklyPuzzle() async {
        puzzleService.purgeWeeklyCache()
        weeklyPuzzle = nil
        weeklyProgress = nil
        do {
            let weekly = try await puzzleService.fetchCurrentWeeklyPuzzle()
            weeklyPuzzle = weekly
            weeklyProgress = UserProgress.load(puzzleId: weekly.id)
        } catch {}
    }

    /// Deletes saved progress for a puzzle, resetting it to New.
    func debugResetPuzzle(puzzle: Puzzle, isWeekly: Bool) {
        UserProgress.delete(puzzleId: puzzle.id)
        if isWeekly {
            weeklyProgress = nil
        } else {
            todaysProgress = nil
        }
    }

    /// Sets the sample puzzle as completed in-memory for Xcode previews.
    func debugSetSampleCompleted() {
        previewMode = true
        let puzzle = Puzzle.sample
        var progress = UserProgress(puzzleId: puzzle.id, size: puzzle.size,
                                    puzzleDate: puzzle.date, totalClues: puzzle.clues.count, isWeekly: false)
        for clue in puzzle.clues {
            let letters = Array(clue.answer)
            for (offset, letter) in letters.enumerated() {
                switch clue.direction {
                case .across: progress.entries[clue.startRow][clue.startCol + offset] = String(letter)
                case .down:   progress.entries[clue.startRow + offset][clue.startCol] = String(letter)
                }
            }
            progress.completedClueIds.insert(clue.id)
        }
        progress.completedAt = Date()
        progress.startedAt = Date().addingTimeInterval(-(2 * 3600 + 45 * 60))
        todaysPuzzle = puzzle
        todaysProgress = progress
        isLoading = false
    }
}
#endif
