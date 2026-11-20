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
    var fillFraction: Double? = nil
    var progressDetail: String? = nil
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
            status = progressDetail.map { "In progress, \($0)" } ?? "In progress"
        case .finished(let won): status = won ? "Finished, solved" : "Finished without a win"
        }
        return "\(game.displayName): \(status)"
    }
}

struct DailyChallengeSnapshot: Equatable {
    let date: String
    private(set) var games: [DailyChallengeGameProgress]
    private(set) var nextAnagramProgressTick: Date?

    private static let anagramIntervalSeconds = 30
    private static let anagramMaximumIntervals = 6
    private static let maximumGuesses = 5
    static let maximumPointsPerGame = 5
    static var maximumDailyPoints: Int { DailyChallengeGame.allCases.count * maximumPointsPerGame }

    var finishedCount: Int { games.filter(\.isFinished).count }
    var isComplete: Bool { finishedCount == DailyChallengeGame.allCases.count }
    var earnedPoints: Int { games.reduce(0) { $0 + $1.earnedPoints } }
    var possiblePoints: Int { Self.maximumDailyPoints }

    subscript(game: DailyChallengeGame) -> DailyChallengeGameProgress {
        games.first { $0.game == game }!
    }

    #if DEBUG
    /// In-memory display data only; never written to game progress or ratings.
    static func celebrationPreview(date: String) -> DailyChallengeSnapshot {
        var preview = DailyChallengeSnapshot(date: date)
        for (game, points) in zip(DailyChallengeGame.allCases, [5, 4, 3, 0]) {
            preview.set(game, state: .finished(won: points > 0), earnedPoints: points)
        }
        return preview
    }
    #endif

    init(
        date: String,
        backword: BackwordProgress? = nil,
        crosswords: [UserProgress] = [],
        dailyPuzzle: Puzzle? = nil,
        anagram: AnagramProgress? = nil,
        midword: MidwordProgress? = nil,
        now: Date = Date()
    ) {
        self.date = date
        games = DailyChallengeGame.allCases.map { DailyChallengeGameProgress(game: $0, state: .notStarted) }
        nextAnagramProgressTick = nil
        if let backword, backword.date == date {
            let finished = backword.isComplete
            let guesses = backword.guesses.count
            set(.backword, state: backword.isComplete ? .finished(won: backword.isWon)
                : backword.guesses.isEmpty && !backword.clueRevealed ? .notStarted : .inProgress,
                fraction: !finished && guesses > 0 ? Self.guessFraction(guesses) : nil,
                progressDetail: !finished && guesses > 0
                    ? "\(guesses) of \(Self.maximumGuesses) guesses used" : nil,
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
            // The loaded grid is authoritative when saved clue-count metadata
            // is stale. Without it, an unfinished record still needs room for
            // at least one unanswered clue in its progress fraction.
            let loadedClueCount = currentPuzzle?.clues.count ?? 0
            let total = loadedClueCount > 0 ? loadedClueCount : (crossword.totalClues ?? 0)
            let completedCount = crossword.completedClueIds.count
            let progressTotal = max(total, completedCount + 1)
            let points: Int
            if crossword.gaveUpAt != nil {
                // Giving up reveals the remaining clues; retain only the
                // score earned before that reveal.
                points = crossword.gaveUpScore ?? crossword.releaseDateScore
            } else if total > 0 {
                let percent = Int(min(1, Double(completedCount) / Double(total)) * 100)
                points = Int.crosswordScore(percentComplete: percent) - crossword.hintsUsed / 3
            } else {
                points = crossword.releaseDateScore
            }
            set(.crossword, state: finished ? .finished(won: crossword.gaveUpAt == nil) : .inProgress,
                fraction: !finished && total > 0
                    ? Double(completedCount) / Double(progressTotal) : nil,
                progressDetail: !finished && total > 0
                    ? "\(completedCount) of \(progressTotal) answers completed" : nil,
                completedAt: crossword.completedAt ?? crossword.gaveUpAt, earnedPoints: points)
        }
        if let anagram, anagram.date == date {
            let finished = anagram.isComplete && anagram.completedAt != nil
            let intervals = min(anagram.elapsedSeconds(at: now) / Self.anagramIntervalSeconds,
                                Self.anagramMaximumIntervals)
            if !finished && intervals < Self.anagramMaximumIntervals {
                nextAnagramProgressTick = anagram.startedAt.addingTimeInterval(
                    TimeInterval((intervals + 1) * Self.anagramIntervalSeconds)
                )
            }
            set(.anagram, state: finished ? .finished(won: anagram.outcome == .solved) : .inProgress,
                fraction: !finished ? Double(intervals) / Double(Self.anagramMaximumIntervals + 1) : nil,
                progressDetail: !finished ? "\(intervals) 30-second intervals elapsed" : nil,
                completedAt: anagram.completedAt, earnedPoints: anagram.releaseDateScore)
        }
        if let midword, midword.date == date {
            let finished = midword.isComplete
            let started = midword.startedAt != nil
            let intervals = min(6, midword.elapsedSeconds(at: now) / 30)
            if !finished, let start = midword.startedAt, intervals < 6 {
                let next = start.addingTimeInterval(TimeInterval((intervals + 1) * 30))
                nextAnagramProgressTick = min(nextAnagramProgressTick ?? next, next)
            }
            set(.midword, state: finished ? .finished(won: midword.isWon)
                : started || !midword.guesses.isEmpty ? .inProgress : .notStarted,
                fraction: !finished && started ? Double(intervals) / 7 : nil,
                progressDetail: !finished && started ? "\(intervals) 30-second intervals elapsed" : nil,
                completedAt: midword.completedAt, earnedPoints: midword.releaseDateScore)
        }
    }

    private static func guessFraction(_ count: Int) -> Double {
        Double(min(max(0, count), maximumGuesses - 1)) / Double(maximumGuesses)
    }

    private mutating func set(
        _ game: DailyChallengeGame, state: DailyChallengeGameProgress.State,
        fraction: Double? = nil, progressDetail: String? = nil,
        completedAt: Date? = nil, earnedPoints: Int = 0
    ) {
        guard let index = games.firstIndex(where: { $0.game == game }) else { return }
        games[index] = DailyChallengeGameProgress(
            game: game, state: state, fillFraction: fraction, progressDetail: progressDetail,
            completedAt: completedAt,
            earnedPoints: min(Self.maximumPointsPerGame, max(0, earnedPoints))
        )
    }
}
