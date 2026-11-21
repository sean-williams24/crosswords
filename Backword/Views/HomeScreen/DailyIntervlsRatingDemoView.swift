import SwiftUI

struct DailyIntervlsRatingDemoView: View, Animatable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var progress: Double
    let isPro: Bool
    var hidesTrack = false

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let example = DailyIntervlsRatingExample(fraction: reduceMotion ? 1 : progress, isPro: isPro)
        let tier = example.tier
        VStack(spacing: AppLayout.homeDailyCelebrationRowSpacing) {
            Text("\(example.points) / \(example.maximumPoints) pts")
                .font(AppFont.statNumber(AppLayout.dailyIntervlsGuidePointsSize))
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            RatingProgressTrack(
                fraction: example.fraction,
                style: .detailed(markerColor: tier.color, pulses: false, markerAnimationDelay: 0),
                animates: true,
                animatesProgressChanges: false
            )
            .opacity(hidesTrack ? 0 : 1)
            .animation(nil, value: hidesTrack)
            .anchorPreference(key: HomeRatingHandoffAnchors.self, value: .bounds) { bounds in
                HomeRatingHandoffAnchors.Value(guide: .init(bounds: bounds, fraction: example.fraction))
            }
            RatingBarLabelLayout(fraction: example.fraction, placement: .fullWidth) {
                ZStack {
                    // Keep the same label width while the active tier fades in.
                    ForEach(RatingTier.allCases, id: \.self) { tier in
                        RatingBarTierLabel(tier: tier)
                            .opacity(example.labelOpacity(for: tier))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
            .animation(nil, value: example.fraction)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(OverallRating.windowDays)-day rating example")
        .accessibilityValue("\(RatingTier.novice.displayName) at zero points to \(RatingTier.virtuoso.displayName) at \(example.maximumPoints) points")
    }
}
