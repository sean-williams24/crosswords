import SwiftUI
import UIKit

struct HomeDailyChallengeCelebration: View {
    static let title = "Todays Intervls Complete"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var sequence = DailyChallengeCelebrationViewModel()
    @AccessibilityFocusState private var titleFocused: Bool
    let snapshot: DailyChallengeSnapshot
    let dismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.opacity(0.88)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                ViewThatFits(in: .vertical) {
                    cardContent
                        .background(cardBackground)
                        .fixedSize(horizontal: false, vertical: true)
                    ScrollView {
                        cardContent
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.homeDailyCelebrationCornerRadius))
                    .background(cardBackground)
                }
                .frame(width: max(0, min(AppLayout.homeDailyCelebrationMaxWidth,
                    geometry.size.width - AppLayout.homeDailyCelebrationMargin * 2)))
                .frame(maxHeight: max(0, geometry.size.height - AppLayout.homeDailyCelebrationMargin * 2))
                .padding(AppLayout.homeDailyCelebrationMargin)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
        .task(id: reduceMotion) {
            titleFocused = true
            await sequence.reveal(reduceMotion: reduceMotion)
            guard !Task.isCancelled else { return }
            UIAccessibility.post(notification: .announcement,
                                 argument: "Daily total, \(snapshot.earnedPoints) of \(snapshot.possiblePoints) points")
        }
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.72), value: sequence.step)
    }

    private var cardContent: some View {
        VStack(spacing: AppLayout.homeDailyCelebrationSpacing) {
            heading

            VStack(spacing: AppLayout.homeDailyCelebrationRowSpacing) {
                ForEach(snapshot.games) { progress in
                    HomeDailyChallengeCelebrationRow(
                        progress: progress,
                        showsGame: sequence.showsGame(progress.game),
                        showsPoints: sequence.showsPoints(progress.game)
                    )
                }
            }

            total

            Button(action: dismiss) {
                Text("Continue")
                    .font(AppFont.clueLabel())
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(AppLayout.homeDailyCelebrationPadding)
                    .background(Color.solvedGold.opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.solvedGold.opacity(0.4),
                                                   lineWidth: AppLayout.homeDailyCardBorderWidth))
            }
            .buttonStyle(.plain)
        }
        .padding(AppLayout.homeDailyCelebrationCardPadding)
    }

    private var heading: some View {
        Text(Self.title)
            .font(AppFont.header(AppLayout.homeDailyCelebrationTitleSize))
            .foregroundStyle(Color.appTextPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($titleFocused)
    }

    private var total: some View {
        VStack(spacing: AppLayout.homeDailyMarkerSpacing) {
            Text("DAILY TOTAL")
                .font(AppFont.clueLabel())
                .tracking(2)
                .foregroundStyle(Color.appTextSecondary)
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: AppLayout.homeDailyMarkerSpacing) { totalValue }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: AppLayout.homeDailyMarkerSpacing) { totalValue }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppLayout.homeDailyCelebrationPadding)
        .background(Color.solvedGold.opacity(0.08), in: RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .opacity(sequence.showsTotal ? 1 : 0)
        .scaleEffect(sequence.showsTotal || reduceMotion ? 1 : 0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily total, \(snapshot.earnedPoints) of \(snapshot.possiblePoints) points")
        .accessibilityHidden(!sequence.showsTotal)
    }

    @ViewBuilder
    private var totalValue: some View {
        Text("\(snapshot.earnedPoints)")
            .font(AppFont.statNumber(AppLayout.homeDailyCelebrationTotalSize))
            .foregroundStyle(Color.solvedGold)
            .monospacedDigit()
        Text("/ \(snapshot.possiblePoints)")
            .font(AppFont.body())
            .foregroundStyle(Color.solvedGold)
            .monospacedDigit()
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppLayout.homeDailyCelebrationCornerRadius)
            .fill(Color.appSurface)
            .overlay {
                RoundedRectangle(cornerRadius: AppLayout.homeDailyCelebrationCornerRadius)
                    .strokeBorder(Color.solvedGold.opacity(sequence.showsTotal ? 0.65 : 0.25),
                                  lineWidth: AppLayout.homeDailyCardBorderWidth)
            }
            .shadow(color: Color.solvedGold.opacity(sequence.showsTotal ? 0.2 : 0.06),
                    radius: AppLayout.homeDailyCelebrationSpacing)
    }
}

#if DEBUG
#Preview("Celebration · Animated · Dark") {
    HomeDailyChallengeCelebration(
        snapshot: .celebrationPreview(date: ContentReleaseCalendar().dailyDateString),
        dismiss: {}
    )
    .background(AppBackgroundGradient())
    .preferredColorScheme(.dark)
}

#Preview("Celebration · Full Result · Light") {
    HomeDailyChallengeCelebration(
        snapshot: .celebrationPreview(date: ContentReleaseCalendar().dailyDateString),
        dismiss: {}
    )
    .background(AppBackgroundGradient())
    .preferredColorScheme(.light)
    .environment(\._accessibilityReduceMotion, true)
}

#Preview("Celebration · Accessibility") {
    HomeDailyChallengeCelebration(
        snapshot: .celebrationPreview(date: ContentReleaseCalendar().dailyDateString),
        dismiss: {}
    )
    .background(AppBackgroundGradient())
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
    .environment(\._accessibilityReduceMotion, true)
}
#endif
