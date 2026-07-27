import SwiftUI

struct RatingProgressTrack: View {
    enum Style {
        case simple
        case detailed(
            markerColor: Color,
            pulses: Bool,
            markerAnimationDelay: Double
        )

        var height: CGFloat {
            switch self {
            case .simple:
                return 8
            case .detailed:
                return 18
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .simple:
                return 0
            case .detailed:
                return 20
            }
        }

        var trackColor: Color {
            switch self {
            case .simple:
                return .appBackground
            case .detailed:
                return .appSurface
            }
        }
    }

    let fraction: Double
    let style: Style
    let animates: Bool

    private var clampedFraction: CGFloat {
        CGFloat(min(max(fraction, 0), 1))
    }

    private var displayedFraction: CGFloat {
        animates ? clampedFraction : 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(style.trackColor)
                    .frame(height: 8)
                    .cornerRadius(style.cornerRadius)

                Rectangle()
                    .fill(Self.barGradient)
                    .frame(height: 8)
                    .cornerRadius(style.cornerRadius)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(
                                width: max(
                                    geometry.size.width * displayedFraction,
                                    6
                                )
                            )
                            .cornerRadius(style.cornerRadius)
                    }
                    .animation(
                        .spring(response: 0.8, dampingFraction: 0.75),
                        value: displayedFraction
                    )

                if case let .detailed(markerColor, pulses, markerAnimationDelay) = style {
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
        }
        .frame(height: style.height)
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

    var body: some View {
        RatingProgressTrack(
            fraction: rating.fraction(for: category),
            style: .simple,
            animates: animates
        )
        .frame(maxWidth: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                animates = true
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
