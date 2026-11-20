import SwiftUI

struct DailyIntervlsRatingDemoView: View, Animatable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var progress: Double
    let isPro: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let example = DailyIntervlsRatingExample(fraction: reduceMotion ? 1 : progress, isPro: isPro)
        VStack(spacing: AppLayout.homeDailyCelebrationRowSpacing) {
            Text("\(OverallRating.windowDays)-day example")
                .font(AppFont.caption())
                .foregroundStyle(Color.appTextSecondary)
            Text("\(example.points) / \(example.maximumPoints) pts")
                .font(AppFont.statNumber(AppLayout.homeDailyCelebrationScoreSize))
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            RatingProgressTrack(
                fraction: example.fraction,
                style: .detailed(markerColor: example.tier.color, pulses: false, markerAnimationDelay: 0),
                animates: true,
                animatesProgressChanges: false
            )
            RatingBarLabelLayout(fraction: example.fraction) {
                RatingBarTierLabel(tier: example.tier)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(OverallRating.windowDays)-day rating example")
        .accessibilityValue("\(RatingTier.novice.displayName) at zero points to \(RatingTier.virtuoso.displayName) at \(example.maximumPoints) points")
    }
}
