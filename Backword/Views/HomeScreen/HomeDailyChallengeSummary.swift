import SwiftUI

struct HomeDailyChallengeSummary: View {
    let snapshot: DailyChallengeSnapshot
    var celebrationID = 0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppLayout.homeDailySummarySpacing) {
                pointsLabel
                markers
            }
            VStack(alignment: .trailing, spacing: AppLayout.homeDailySummaryLineSpacing) {
                pointsLabel
                markers
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's daily challenge, \(snapshot.earnedPoints) of \(snapshot.possiblePoints) points, \(snapshot.finishedCount) of 4 games finished")
    }

    private var pointsLabel: some View {
        Text("TODAY - \(snapshot.earnedPoints)/\(snapshot.possiblePoints) PTS")
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
