import SwiftUI

/// Compact rating bar shown on HomeView. Tappable to open RatingDetailSheet.
struct RatingBarView: View {
    let rating: OverallRating
    let isPro: Bool

    @State private var animates = false
    @State private var showDetail = false

    private var tier: RatingTier { rating.tier(isPro: isPro) }
    private var fraction: Double { rating.fraction(isPro: isPro) }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(spacing: 8) {
                // Bar track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Bar track (8pt, centered vertically in the ZStack)
                        Capsule()
                            .fill(Color.appSurface)
                            .frame(height: 8)

                        // Gradient fill, masked to filled portion
                        Rectangle()
                            .fill(barGradient)
                            .frame(height: 8)
                            .mask(alignment: .leading) {
                                Capsule()
                                    .frame(width: animates ? max(geo.size.width * CGFloat(fraction), 6) : 6)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.75), value: animates)
                            }

                        // Dot (18pt — protrudes above/below the 8pt bar)
                        ZStack {
                            Circle()
                                .fill(tier.color.opacity(0.3))
                                .frame(width: 18, height: 18)
                            Circle()
                                .strokeBorder(tier.color, lineWidth: 2)
                                .frame(width: 14, height: 14)
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        }
                        .shadow(color: tier.color.opacity(0.5), radius: 4, x: 0, y: 0)
                        .offset(x: animates ? max(geo.size.width * CGFloat(fraction) - 9, 0) : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.05), value: animates)
                    }
                }
                .frame(height: 18)

                // Tier label aligned under the dot
                GeometryReader { geo in
                    tierLabel
                        .offset(x: labelOffset(barWidth: geo.size.width))
                }
                .frame(height: 20)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            RatingDetailSheet(rating: rating, isPro: isPro) {
                showDetail = false
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animates = true
            }
        }
    }

    // MARK: - Helpers

    private var tierLabel: some View {
        HStack(spacing: 4) {
            if tier == .virtuoso {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tier.gradient)
            }
            Text(tier.displayName.uppercased())
                .font(AppFont.clueLabel(10))
                .foregroundColor(tier.color)
                .tracking(1.5)
        }
    }

    private func labelOffset(barWidth: CGFloat) -> CGFloat {
        // Centre the label under the dot, clamped to bar bounds
        let dotX = barWidth * CGFloat(fraction)
        let labelWidth: CGFloat = CGFloat(tier.displayName.count) * 7.5 + (tier == .virtuoso ? 16 : 0)
        let ideal = dotX - labelWidth / 2
        return max(0, min(ideal, barWidth - labelWidth))
    }

    /// A gradient that covers all tier colours from left to right, so the filled bar
    /// colour progression matches the position on the bar.
    private var barGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white,                                         location: 0.0),
                .init(color: Color(white: 0.72),                             location: 1.0 / 7.0),
                .init(color: RatingTier.dabbler.color.opacity(0.6),          location: 2.0 / 7.0),
                .init(color: RatingTier.penman.color,                        location: 3.0 / 7.0),
                .init(color: RatingTier.linguist.color,                      location: 4.0 / 7.0),
                .init(color: RatingTier.grandmaster.color,                   location: 5.0 / 7.0),
                .init(color: Color(red: 0.95, green: 0.8, blue: 0.3),       location: 6.0 / 7.0),
                .init(color: Color(red: 0.85, green: 0.55, blue: 0.15),     location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private func makePreviewRating(days: Int, daily: Int, backword: Int) -> OverallRating {
    var r = OverallRating()
    for i in 0..<days {
        let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
        let ds = OverallRating.dateFormatter.string(from: d)
        r.upsertDailyCrossword(score: daily, date: ds)
        r.upsertBackword(score: backword, date: ds)
    }
    return r
}

#Preview {
    VStack(spacing: 40) {
        RatingBarView(rating: makePreviewRating(days: 7, daily: 2, backword: 1), isPro: false)
        RatingBarView(rating: makePreviewRating(days: 7, daily: 6, backword: 1), isPro: false)
        RatingBarView(rating: makePreviewRating(days: 7, daily: 8, backword: 1), isPro: false)
        RatingBarView(rating: makePreviewRating(days: 7, daily: 8, backword: 6), isPro: false)
        RatingBarView(rating: makePreviewRating(days: 14, daily: 5, backword: 5), isPro: false)
        RatingBarView(rating: OverallRating(), isPro: false)
    }
    .padding(40)
    .background(Color.appBackground)
}
