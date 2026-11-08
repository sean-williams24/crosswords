import Foundation

enum DailyChallengeGame: String, CaseIterable, Identifiable {
    case backword, crossword, anagram, midword

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backword: return "Backword"
        case .crossword: return "Quick Crossword"
        case .anagram: return "Anagram"
        case .midword: return "Midword"
        }
    }
}

struct DailyChallengeGameProgress: Equatable, Identifiable {
    enum State: Equatable {
        case notStarted
        case inProgress
        case finished(won: Bool)
    }

    let game: DailyChallengeGame
    let state: State
    var crosswordFraction: Double? = nil
    var completedAt: Date? = nil
    var earnedPoints = 0

    var id: DailyChallengeGame { game }
    var isFinished: Bool {
        if case .finished = state { return true }
        return false
    }

    var accessibilityLabel: String {
        let status: String
        switch state {
        case .notStarted: status = "Not started"
        case .inProgress:
            status = crosswordFraction.map { "In progress, \(Int($0 * 100)) percent" } ?? "In progress"
        case .finished(let won): status = won ? "Finished, solved" : "Finished without a win"
        }
        return "\(game.displayName): \(status)"
    }
}

struct DailyChallengeSnapshot: Equatable {
    let date: String
    private(set) var games: [DailyChallengeGameProgress]

    var finishedCount: Int { games.filter(\.isFinished).count }
    var isComplete: Bool { finishedCount == DailyChallengeGame.allCases.count }
    var earnedPoints: Int { games.reduce(0) { $0 + $1.earnedPoints } }
    var possiblePoints: Int { DailyChallengeGame.allCases.count * 5 }

    subscript(game: DailyChallengeGame) -> DailyChallengeGameProgress {
        games.first { $0.game == game }!
    }

    init(
        date: String,
        backword: BackwordProgress? = nil,
        crosswords: [UserProgress] = [],
        dailyPuzzle: Puzzle? = nil,
        anagram: AnagramProgress? = nil,
        midword: MidwordProgress? = nil
    ) {
        self.date = date
        games = DailyChallengeGame.allCases.map { DailyChallengeGameProgress(game: $0, state: .notStarted) }
        if let backword, backword.date == date {
            set(.backword, state: backword.isComplete ? .finished(won: backword.isWon)
                : backword.guesses.isEmpty && !backword.clueRevealed ? .notStarted : .inProgress,
                completedAt: backword.completedAt, earnedPoints: backword.completedScore ?? 0)
        }
        // A loaded puzzle can identify legacy records without date metadata.
        // Otherwise only explicit daily release metadata can identify today's grid.
        let currentPuzzle = dailyPuzzle.flatMap { $0.date == date ? $0 : nil }
        let crossword = crosswords.filter { progress in
            guard progress.isWeekly != true else { return false }
            if let puzzleDate = progress.puzzleDate, puzzleDate != date { return false }
            if let currentPuzzle { return progress.puzzleId == currentPuzzle.id }
            return progress.puzzleDate == date && progress.isWeekly == false
        }.max { $0.updatedAt < $1.updatedAt }
        if let crossword {
            let finished = crossword.isComplete || crossword.gaveUpAt != nil
            let total = crossword.totalClues ?? currentPuzzle?.clues.count ?? 0
            let points: Int
            if crossword.gaveUpAt != nil {
                // Giving up reveals the remaining clues; retain only the
                // score earned before that reveal.
                points = crossword.gaveUpScore ?? crossword.releaseDateScore
            } else if total > 0 {
                let percent = Int(min(1, Double(crossword.completedClueIds.count) / Double(total)) * 100)
                points = Int.crosswordScore(percentComplete: percent) - crossword.hintsUsed / 3
            } else {
                points = crossword.releaseDateScore
            }
            set(.crossword, state: finished ? .finished(won: crossword.gaveUpAt == nil) : .inProgress,
                fraction: !finished && total > 0
                    ? min(1, Double(crossword.completedClueIds.count) / Double(total)) : nil,
                completedAt: crossword.completedAt ?? crossword.gaveUpAt, earnedPoints: points)
        }
        if let anagram, anagram.date == date {
            set(.anagram, state: anagram.isComplete && anagram.completedAt != nil
                ? .finished(won: anagram.outcome == .solved) : .inProgress,
                completedAt: anagram.completedAt, earnedPoints: anagram.releaseDateScore)
        }
        if let midword, midword.date == date {
            set(.midword, state: midword.isComplete ? .finished(won: midword.isWon)
                : midword.guesses.isEmpty ? .notStarted : .inProgress,
                completedAt: midword.completedAt, earnedPoints: midword.releaseDateScore)
        }
    }

    private mutating func set(
        _ game: DailyChallengeGame, state: DailyChallengeGameProgress.State,
        fraction: Double? = nil, completedAt: Date? = nil, earnedPoints: Int = 0
    ) {
        guard let index = games.firstIndex(where: { $0.game == game }) else { return }
        games[index] = DailyChallengeGameProgress(
            game: game, state: state, crosswordFraction: fraction, completedAt: completedAt,
            earnedPoints: min(5, max(0, earnedPoints))
        )
    }
}
