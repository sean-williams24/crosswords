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

    init(puzzleService: PuzzleService) {
        self.puzzleService = puzzleService
    }

    func refreshIfNeeded(isProUser: Bool) async {
        let today = formattedToday()
        let dailyStale = todaysPuzzle?.date != today
        let weeklyStale = isProUser && weeklyPuzzleIsStale()

        guard dailyStale || weeklyStale else { return }
        await loadTodaysPuzzle()
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
