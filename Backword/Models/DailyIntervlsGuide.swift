import Foundation

enum DailyIntervlsGuideStep: Equatable {
    case gameplay
    case scoring

    var title: String {
        switch self {
        case .gameplay: return "Your Daily Intervls"
        case .scoring: return "Points and rating"
        }
    }

    var introduction: String {
        switch self {
        case .gameplay:
            return "Finish all four daily games before midnight, score a maximum of 20 points."
        case .scoring:
            return "Up to \(DailyChallengeSnapshot.maximumPointsPerGame) points per game, \(DailyChallengeSnapshot.maximumDailyPoints) points per day."
        }
    }

    func actionTitle(isOnboarding: Bool) -> String {
        switch self {
        case .gameplay: return "OK"
        case .scoring: return isOnboarding ? "Lets play" : "Done"
        }
    }

    static var ratingDescription: String {
        "Your tier is based on your share of available points over the last \(OverallRating.windowDays) days. Missed games score zero."
    }

    static let eligibilityDescription = "Archive play earns no rating points. Weekly Pro Crossword points count toward the Pro rating."
}

extension DailyChallengeGame {
    var guideScoringDescription: String {
        switch self {
        case .backword:
            return "Fewer guesses earn more points."
        case .crossword:
            return "Complete more clues for more points. Lose 1 point per 3 hints."
        case .anagram, .midword:
            return "Faster solves earn more points."
        }
    }
}
