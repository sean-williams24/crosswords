import SwiftUI

struct HomeDailyChallengeCelebrationRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var minimumHeight = AppLayout.homeDailyCelebrationRowHeight
    let progress: DailyChallengeGameProgress
    let showsGame: Bool
    let showsPoints: Bool

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppLayout.homeDailyCelebrationRowSpacing) {
                    logo
                    HStack {
                        Spacer()
                        points
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: AppLayout.homeDailyCelebrationPadding) {
                    logo
                        .frame(maxWidth: .infinity, alignment: .leading)
                    points
                }
            }
        }
        .frame(minHeight: minimumHeight)
        .padding(.horizontal, AppLayout.homeDailyCelebrationPadding)
        .padding(.vertical, AppLayout.homeDailyCelebrationRowSpacing)
        .background(progress.game.homeProgressColor.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .opacity(showsGame ? 1 : 0)
        .offset(y: showsGame || reduceMotion ? 0 : AppLayout.homeDailyCelebrationRevealOffset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(progress.game.displayName), \(progress.earnedPoints) of 5 points")
        .accessibilityHidden(!showsPoints)
    }

    private var logo: some View {
        HomeDailyChallengeCelebrationLogo(game: progress.game)
    }

    private var points: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppLayout.homeDailyMarkerSpacing) {
            Text("\(progress.earnedPoints)")
                .font(AppFont.statNumber(AppLayout.homeDailyCelebrationScoreSize))
                .foregroundStyle(progress.game.homeProgressColor)
            Text("/ 5")
                .font(AppFont.caption())
                .foregroundStyle(Color.appTextSecondary)
        }
        .monospacedDigit()
        .fixedSize()
        .opacity(showsPoints ? 1 : 0)
        .scaleEffect(showsPoints || reduceMotion ? 1 : 0.6)
    }
}
