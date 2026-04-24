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
                        // Track
                        Capsule()
                            .fill(Color.appSurface)

                        // Filled portion — uses a gradient that shifts colour as fraction grows
                        Capsule()
                            .fill(barGradient)
                            .frame(width: animates ? max(geo.size.width * CGFloat(fraction), 6) : 6)
                            .animation(.spring(response: 0.8, dampingFraction: 0.75), value: animates)

                        // Tier marker dot at current position
                        Circle()
                            .fill(tier.color)
                            .frame(width: 10, height: 10)
                            .offset(x: animates ? max(geo.size.width * CGFloat(fraction) - 5, 0) : 0)
                            .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.05), value: animates)
                    }
                }
                .frame(height: 8)

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
                .init(color: RatingTier.dabbler.color.opacity(0.6), location: 0.0),
                .init(color: RatingTier.penman.color, location: 0.2),
                .init(color: RatingTier.linguist.color, location: 0.4),
                .init(color: RatingTier.grandmaster.color, location: 0.6),
                .init(color: Color(red: 0.95, green: 0.8, blue: 0.3), location: 0.8),
                .init(color: Color(red: 0.85, green: 0.55, blue: 0.15), location: 1.0)
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
