import SwiftUI

struct RatingBarView: View {
    @ScaledMetric private var tierLabelHeight: CGFloat = 20
    @State private var animates = false
    @State private var pulses = false
    @State private var showDetail = false
    private var tier: RatingTier { rating.tier(isPro: isPro) }

    let rating: OverallRating
    let isPro: Bool
    let fraction: Double
    var category: RatingGameCategory? = nil

    private func pointsView(category: RatingGameCategory) -> some View {
        HStack {
            Spacer()
            Text("\(rating.points(for: category))/\(rating.maxPoints(for: category))")
                .font(AppFont.clueLabel(14))
                .foregroundColor(.accentColor)
                .monospacedDigit()
                .background(Color.clear)
        }
    }

    @ViewBuilder
    private var tierLabelView: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                tierLabel
                    .alignmentGuide(.leading) { dimensions in
                        -RatingBarLabelLayout.leadingOffset(
                            barWidth: geo.size.width,
                            fraction: fraction,
                            labelWidth: dimensions.width
                        )
                    }
            }
            .frame(width: geo.size.width, height: tierLabelHeight, alignment: .topLeading)
        }
        .frame(height: tierLabelHeight)
    }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(spacing: 8) {
                // Bar track
                RatingProgressTrack(
                    fraction: fraction,
                    markerColor: tier.color,
                    animates: animates,
                    pulses: pulses,
                    markerAnimationDelay: 0.05,
                    trackType: .detailed
                )

                if let category {
                    pointsView(category: category)
                } else {
                    tierLabelView
                }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                ) {
                    pulses = true
                }
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

}

enum RatingBarLabelLayout {
    static func leadingOffset(barWidth: CGFloat, fraction: Double, labelWidth: CGFloat) -> CGFloat {
        let dotX = barWidth * CGFloat(fraction)
        let ideal = dotX - labelWidth / 2
        if labelWidth > barWidth {
            return barWidth - labelWidth
        }
        return max(0, min(ideal, barWidth - labelWidth))
    }
}

private func makePreviewRating(days: Int, daily: Int, backword: Int) -> OverallRating {
    var r = OverallRating()
    for i in 0..<days {
        let ds = ContentReleaseCalendar().dailyDateString(offsetByDays: -i)!
        r.upsertDailyCrossword(score: daily, date: ds)
        r.upsertBackword(score: backword, date: ds)
    }
    return r
}

#Preview {
    let r1 = makePreviewRating(days: 14, daily: 3, backword: 5)
    VStack(spacing: 40) {
        RatingBarView(rating: r1, isPro: false, fraction: r1.fraction(for: .dailyCrossword), category: .backword)
        RatingBarView(rating: makePreviewRating(days: 7, daily: 6, backword: 1), isPro: false, fraction: 0.8)
        RatingBarView(rating: makePreviewRating(days: 7, daily: 8, backword: 1), isPro: false, fraction: 0.3)
//        RatingBarView(rating: makePreviewRating(days: 7, daily: 8, backword: 6), isPro: false)
//        RatingBarView(rating: makePreviewRating(days: 14, daily: 5, backword: 5), isPro: false)
//        RatingBarView(rating: OverallRating(), isPro: false)
    }
    .padding(40)
    .background(Color.appBackground)
}
