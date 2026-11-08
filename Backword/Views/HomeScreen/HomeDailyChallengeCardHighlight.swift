import SwiftUI

struct HomeDailyChallengeCardHighlight: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: DailyChallengeGameProgress
    var isCurrentRelease = true

    func body(content: Content) -> some View {
        content
            .overlay {
                if progress.isFinished && isCurrentRelease {
                    RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                        .strokeBorder(progress.game.homeProgressColor.opacity(0.7),
                                      lineWidth: AppLayout.homeDailyCardBorderWidth)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: progress.isFinished)
    }
}
