import SwiftUI

struct HomeDailyChallengeSummary: View {
    let snapshot: DailyChallengeSnapshot
    var celebrationID = 0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppLayout.homeDailySummarySpacing) {
                countLabel
                markers
            }
            VStack(alignment: .trailing, spacing: AppLayout.homeDailySummaryLineSpacing) {
                countLabel
                markers
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's daily challenge, \(snapshot.finishedCount) of 4 finished")
    }

    private var countLabel: some View {
        Text("TODAY \(snapshot.finishedCount)/4")
            .font(AppFont.clueLabel(AppLayout.homeDailyLabelSize))
            .monospacedDigit()
            .foregroundStyle(snapshot.isComplete ? Color.solvedGold : Color.appTextSecondary)
            .fixedSize()
            .accessibilityHidden(true)
    }

    private var markers: some View {
        HStack(spacing: AppLayout.homeDailyMarkerSpacing) {
            ForEach(snapshot.games) { progress in
                HomeDailyChallengeMarker(progress: progress, celebrationID: celebrationID)
            }
        }
        .fixedSize()
    }
}
