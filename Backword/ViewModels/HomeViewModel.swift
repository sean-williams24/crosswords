import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var todaysPuzzle: Puzzle?
    @Published var todaysProgress: UserProgress?
    @Published var weeklyPuzzle: Puzzle?
    @Published var weeklyProgress: UserProgress?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let puzzleService: PuzzleService
    #if DEBUG
    var previewMode = false
    #endif

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
        isLoading = true
        errorMessage = nil

        do {
            let puzzle = try await puzzleService.fetchTodaysPuzzle()
            todaysPuzzle = puzzle
            todaysProgress = UserProgress.load(puzzleId: puzzle.id)
        } catch {
            // Fall back to sample puzzle for development
            todaysPuzzle = .sample
            todaysProgress = UserProgress.load(puzzleId: Puzzle.sample.id)
            errorMessage = nil // Suppress error when using sample
        }

        // Load weekly puzzle (silently fail if none available)
        do {
            let weekly = try await puzzleService.fetchCurrentWeeklyPuzzle()
            weeklyPuzzle = weekly
            weeklyProgress = UserProgress.load(puzzleId: weekly.id)
        } catch {
            // No weekly puzzle available yet — that's fine
        }

        isLoading = false
    }

    var dailyCrosswordScore: Int? {
        guard let progress = todaysProgress,
              let total = progress.totalClues, total > 0,
              progress.completedClueIds.count > 0 else { return nil }
        let pct = Int(Double(progress.completedClueIds.count) / Double(total) * 100)
        return Int.crosswordScore(percentComplete: pct)
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

    enum PuzzleStatus {
        case new
        case inProgress
        case completed(String)

        var label: String {
            switch self {
            case .new: return "New"
            case .inProgress: return "In Progress"
            case .completed(let time): return "Completed in \(time)"
            }
        }

        var icon: String {
            switch self {
            case .new: return "plus.circle.fill"
            case .inProgress: return "pencil.circle.fill"
            case .completed: return "checkmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .new: return .appAccent
            case .inProgress: return .appAccent
            case .completed: return .appCorrect
            }
        }
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
