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

    static let gameplayIntroduction = "Complete all four daily games before midnight, score a maximum of 20 points."

    static let ratingBulletPoints = [
        "Your rating is based on the points you earned over the last \(OverallRating.windowDays) days.",
        "Complete your Intervls everyday to reach the highest tier and stay there.",
        "Each new day replaces the oldest."
    ]

    func actionTitle(isOnboarding: Bool) -> String {
        switch self {
        case .gameplay: return "OK"
        case .scoring: return isOnboarding ? "Lets play" : "Done"
        }
    }
}

struct DailyIntervlsRatingExample {
    let fraction: Double
    let maximumPoints: Int

    init(fraction: Double, isPro: Bool) {
        self.fraction = min(max(fraction, 0), 1)
        let dailyPoints = OverallRating.windowDays * DailyChallengeSnapshot.maximumDailyPoints
        maximumPoints = dailyPoints + (isPro ? RatingGameCategory.weeklyCrossword.maxPoints : 0)
    }

    var points: Int { Int((Double(maximumPoints) * fraction).rounded(.down)) }
    var tier: RatingTier { RatingTier.forFraction(Double(points) / Double(maximumPoints)) }
}
