import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var todaysPuzzle: Puzzle?
    @Published var todaysProgress: UserProgress?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let puzzleService: PuzzleService

    init(puzzleService: PuzzleService) {
        self.puzzleService = puzzleService
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

        isLoading = false
    }

    var puzzleStatus: PuzzleStatus {
        guard let progress = todaysProgress else { return .new }
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
