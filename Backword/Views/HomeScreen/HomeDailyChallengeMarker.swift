import SwiftUI

struct HomeDailyChallengeMarker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var width = AppLayout.homeDailyMarkerWidth
    @ScaledMetric private var height = AppLayout.homeDailyMarkerHeight
    @ScaledMetric private var cornerRadius = AppLayout.homeDailyMarkerCornerRadius
    @State private var scale: CGFloat = 1
    let progress: DailyChallengeGameProgress
    var celebrationID = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                if progress.isFinished {
                    RoundedRectangle(cornerRadius: cornerRadius).fill(progress.game.homeProgressColor)
                } else if progress.state == .inProgress, let fraction = progress.crosswordFraction {
                    Rectangle()
                        .fill(progress.game.homeProgressColor)
                        .frame(width: geometry.size.width * fraction)
                }
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(progress.state == .notStarted ? Color.appTextSecondary : progress.game.homeProgressColor,
                                  lineWidth: AppLayout.homeDailyMarkerBorderWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .frame(width: width, height: height)
        .scaleEffect(x: 1, y: scale)
        .offset(y: scale > 1 ? -AppLayout.homeDailyMarkerCelebrationLift : 0)
        .shadow(color: progress.game.homeProgressColor.opacity(scale > 1 ? 0.6 : 0),
                radius: AppLayout.homeDailyMarkerCelebrationGlow)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progress.accessibilityLabel)
        .task(id: reduceMotion ? 0 : celebrationID) {
            scale = 1
            guard celebrationID > 0, !reduceMotion else { return }
            let index = DailyChallengeGame.allCases.firstIndex(of: progress.game) ?? 0
            do {
                try await Task.sleep(for: .milliseconds(index * 90))
                withAnimation(.easeOut(duration: 0.2)) { scale = AppLayout.homeDailyMarkerCelebrationScale }
                try await Task.sleep(for: .milliseconds(230))
                withAnimation(.easeInOut(duration: 0.3)) { scale = 1 }
            } catch {
                scale = 1
            }
        }
    }
}
