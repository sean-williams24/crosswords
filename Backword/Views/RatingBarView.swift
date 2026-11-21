import SwiftUI

struct RatingBarView: View {
    @ScaledMetric private var tierLabelHeight: CGFloat = 20
    @State private var animates = false
    @State private var pulses = false
    @State private var showDetail = false
    private var tier: RatingTier { rating.tier(isPro: isPro) }
    private var fraction: Double {
        category.map { rating.fraction(for: $0) }
            ?? rating.fraction(isPro: isPro)
    }

    let rating: OverallRating
    let isPro: Bool
    var category: RatingGameCategory? = nil
    var accentColor: Color? = nil
    var trackColor: Color? = nil
    var dailyChallenge: DailyChallengeSnapshot? = nil
    var dailyCelebrationID = 0
    var hidesTrack = false
    var onOpenDetails: (() -> Void)? = nil

    private func pointsView(category: RatingGameCategory) -> some View {
        Text("\(rating.points(for: category))/\(rating.maxPoints(for: category))")
            .font(AppFont.clueLabel(14))
            .foregroundColor(accentColor ?? .accentColor)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var tierLabelView: some View {
        RatingBarLabelLayout(fraction: fraction) {
            RatingBarTierLabel(tier: tier)
        }
        .frame(height: tierLabelHeight, alignment: .top)
    }

    var body: some View {
        Button {
            if let onOpenDetails { onOpenDetails() } else { showDetail = true }
        } label: {
            VStack(spacing: 8) {
                // Bar track
                RatingProgressTrack(
                    fraction: fraction,
                    style: .detailed(
                        markerColor: accentColor ?? tier.color,
                        pulses: pulses,
                        markerAnimationDelay: 0.05
                    ),
                    animates: animates,
                    accentColor: accentColor,
                    trackColor: trackColor
                )
                .opacity(hidesTrack ? 0 : 1)
                .animation(nil, value: hidesTrack)
                .anchorPreference(key: HomeRatingHandoffAnchors.self, value: .bounds) { bounds in
                    HomeRatingHandoffAnchors.Value(home: dailyChallenge == nil ? nil : bounds)
                }

                if let category {
                    pointsView(category: category)
                } else if let dailyChallenge {
                    HomeDailyChallengeRatingRow(snapshot: dailyChallenge, celebrationID: dailyCelebrationID) {
                        RatingBarTierLabel(tier: tier)
                    }
                    .frame(minHeight: tierLabelHeight)
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
        RatingBarView(rating: r1, isPro: false, category: .backword)
        RatingBarView(rating: makePreviewRating(days: 7, daily: 5, backword: 1), isPro: false)
        RatingBarView(rating: OverallRating(), isPro: false)
    }
    .padding(40)
    .background(Color.appBackground)
    .environmentObject(AccountService())
    .environmentObject(StoreService())
}
