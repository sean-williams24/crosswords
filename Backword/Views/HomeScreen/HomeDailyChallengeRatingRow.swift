import SwiftUI

struct HomeDailyChallengeRatingRow<Tier: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let snapshot: DailyChallengeSnapshot
    var celebrationID = 0
    @ViewBuilder var tier: () -> Tier

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppLayout.homeDailySummarySpacing) {
                    tier().fixedSize()
                    Spacer(minLength: AppLayout.homeDailySummarySpacing)
                    summary.fixedSize()
                }
                stacked
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: AppLayout.homeDailySummarySpacing) {
            tier().fixedSize(horizontal: false, vertical: true)
            summary.frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var summary: some View {
        HomeDailyChallengeSummary(snapshot: snapshot, celebrationID: celebrationID)
    }
}
