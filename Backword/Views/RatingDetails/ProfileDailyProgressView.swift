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

            ForEach(snapshot.games) { progress in
                Self.gameRow(progress)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(progress.accessibilityLabel), \(progress.earnedPoints) of 5 points")
            }
        }
        .padding(AppLayout.profileDailyPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
    }

    static func gameRow(_ progress: DailyChallengeGameProgress) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppLayout.profileDailySpacing) {
                HomeDailyChallengeMarker(progress: progress)
                gameTitle(progress.game).fixedSize()
                Spacer(minLength: 0)
                gameStatus(progress).fixedSize()
            }
            VStack(alignment: .leading, spacing: AppLayout.profileDailySpacing) {
                HStack(alignment: .center, spacing: AppLayout.profileDailySpacing) {
                    HomeDailyChallengeMarker(progress: progress)
                    gameTitle(progress.game)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                }
                gameStatus(progress)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private static func gameTitle(_ game: DailyChallengeGame) -> some View {
        Text(game.displayName)
            .font(AppFont.body(14))
            .foregroundColor(.appTextPrimary)
    }

    private static func gameStatus(_ progress: DailyChallengeGameProgress) -> some View {
        Text(status(for: progress))
            .font(AppFont.caption())
            .foregroundColor(.appTextSecondary)
            .multilineTextAlignment(.trailing)
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

    private static func status(for progress: DailyChallengeGameProgress) -> String {
        switch progress.state {
        case .notStarted: return "Not started"
        case .inProgress: return "In progress · \(progress.earnedPoints) pts"
        case .finished: return "Finished · \(progress.earnedPoints) pts"
        }
    }
}
