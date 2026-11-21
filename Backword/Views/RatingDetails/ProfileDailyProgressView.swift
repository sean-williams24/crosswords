import SwiftUI

struct ProfileDailyProgressView: View {
    let snapshot: DailyChallengeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayout.profileDailySpacing) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    title
                    Spacer(minLength: AppLayout.profileDailySpacing)
                    points
                }
                VStack(alignment: .leading, spacing: AppLayout.profileDailySpacing) {
                    title
                    points
                }
            }
            Text("\(snapshot.finishedCount) of \(snapshot.games.count) games finished")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)

            DailyIntervlsLineupView(snapshot: snapshot)
        }
        .padding(AppLayout.profileDailyPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
    }

    private var title: some View {
        Text("TODAY'S INTERVLS")
            .font(AppFont.clueLabel(12))
            .tracking(2)
            .foregroundColor(.appAccent)
            .accessibilityAddTraits(.isHeader)
    }

    private var points: some View {
        Text("\(snapshot.earnedPoints) / \(snapshot.possiblePoints) PTS")
            .font(AppFont.clueLabel(12))
            .monospacedDigit()
            .foregroundColor(.appTextPrimary)
            .fixedSize()
    }
}
