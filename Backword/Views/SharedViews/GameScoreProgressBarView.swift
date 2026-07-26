import SwiftUI

struct RatingProgressTrack: View {
    let fraction: Double
    let markerColor: Color
    let animates: Bool
    let pulses: Bool
    var markerAnimationDelay: Double = 0

    private var clampedFraction: CGFloat {
        CGFloat(min(max(fraction, 0), 1))
    }

    private var displayedFraction: CGFloat {
        animates ? clampedFraction : 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appSurface)
                    .frame(height: 8)

                Rectangle()
                    .fill(Self.barGradient)
                    .frame(height: 8)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(
                                width: max(
                                    geometry.size.width * displayedFraction,
                                    6
                                )
                            )
                    }
                    .animation(
                        .spring(response: 0.8, dampingFraction: 0.75),
                        value: displayedFraction
                    )

                ZStack {
                    Circle()
                        .fill(markerColor.opacity(pulses ? 0.08 : 0.3))
                        .frame(width: 18, height: 18)
                        .scaleEffect(pulses ? 1.7 : 1)
                    Circle()
                        .strokeBorder(markerColor, lineWidth: 2)
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                }
                .shadow(color: markerColor.opacity(0.5), radius: 4)
                .offset(
                    x: max(
                        geometry.size.width * displayedFraction - 9,
                        0
                    )
                )
                .animation(
                    .spring(response: 0.8, dampingFraction: 0.75)
                        .delay(markerAnimationDelay),
                    value: displayedFraction
                )
            }
        }
        .frame(height: 18)
    }

    static var barGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: Color(white: 0.72), location: 1.0 / 7.0),
                .init(color: RatingTier.novice.color.opacity(0.6), location: 2.0 / 7.0),
                .init(color: RatingTier.scribe.color, location: 3.0 / 7.0),
                .init(color: RatingTier.linguist.color, location: 4.0 / 7.0),
                .init(color: RatingTier.grandmaster.color, location: 5.0 / 7.0),
                .init(color: Color(red: 0.95, green: 0.8, blue: 0.3), location: 6.0 / 7.0),
                .init(color: Color(red: 0.85, green: 0.55, blue: 0.15), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct GameScoreProgressBarView: View {
    let rating: OverallRating
    let category: RatingGameCategory

    @State private var animates = false
    @State private var pulses = false
    @ScaledMetric private var scoreBoxWidth: CGFloat = 68

    private var points: Int {
        rating.points(for: category)
    }

    private var maximumPoints: Int {
        rating.maxPoints(for: category)
    }

    var body: some View {
        HStack(spacing: 0) {
            RatingProgressTrack(
                fraction: rating.fraction(for: category),
                markerColor: rating.tier(for: category).color,
                animates: animates,
                pulses: pulses
            )

            Text("\(points)/\(maximumPoints)")
                .font(AppFont.clueLabel(14))
                .foregroundColor(.appTextPrimary)
                .monospacedDigit()
//                .frame(minWidth: scoreBoxWidth, minHeight: 14)
                .background(Color.appSurface)
        }
        .frame(maxWidth: .infinity)
        .padding(.trailing, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(category.displayName) rolling score \(points) out of \(maximumPoints)"
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                animates = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                withAnimation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                ) {
                    pulses = true
                }
            }
        }
    }
}

#Preview {
    var rating = OverallRating()
    rating.upsertDailyCrossword(
        score: 5,
        date: ContentReleaseCalendar().dailyDateString
    )
    rating.upsertBackword(
        score: 4,
        date: ContentReleaseCalendar().dailyDateString
    )

    return VStack(spacing: 28) {
        GameScoreProgressBarView(rating: rating, category: .backword)
        GameScoreProgressBarView(rating: rating, category: .dailyCrossword)
        GameScoreProgressBarView(rating: rating, category: .weeklyCrossword)
    }
    .background(Color.appBackground)
}
