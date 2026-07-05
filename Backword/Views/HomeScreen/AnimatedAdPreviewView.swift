import SwiftUI

struct AnimatedAdPreviewView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cycleDuration: TimeInterval = 3.4
    private let progressDuration: TimeInterval = 2.2
    private let closeRevealDelay: TimeInterval = 0.15

    var body: some View {
        TimelineView(.animation) { timeline in
            let state = animationState(at: timeline.date)

            phonePreview(
                progress: reduceMotion ? 1 : state.progress,
                closeVisibility: reduceMotion ? 1 : state.closeVisibility,
                highlightScale: reduceMotion ? 1 : state.highlightScale,
                highlightOpacity: reduceMotion ? 0.45 : state.highlightOpacity
            )
        }
        .aspectRatio(0.64, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func animationState(at date: Date) -> PreviewAnimationState {
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleDuration)
        let progress = min(phase / progressDuration, 1)
        let revealPhase = max(phase - progressDuration - closeRevealDelay, 0)
        let closeVisibility = min(revealPhase / 0.25, 1)
        let pulse = max(phase - progressDuration, 0)
        let highlightOpacity = closeVisibility * (0.28 + 0.22 * sin(pulse * .pi * 2.2))
        let highlightScale = 1 + closeVisibility * (0.08 + 0.04 * sin(pulse * .pi * 2.2))

        return PreviewAnimationState(
            progress: progress,
            closeVisibility: closeVisibility,
            highlightScale: highlightScale,
            highlightOpacity: highlightOpacity
        )
    }

    private func phonePreview(
        progress: Double,
        closeVisibility: Double,
        highlightScale: Double,
        highlightOpacity: Double
    ) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let phoneCornerRadius = width * 0.13
            let adInset = width * 0.1
            let closeSize = width * 0.15

            ZStack {
                RoundedRectangle(cornerRadius: phoneCornerRadius)
                    .fill(Color.appSurface.opacity(0.34))
                    .overlay(
                        RoundedRectangle(cornerRadius: phoneCornerRadius)
                            .stroke(Color.appTextSecondary.opacity(0.7), lineWidth: 2.5)
                    )

                VStack(spacing: width * 0.08) {
                    Capsule()
                        .fill(Color.appTextSecondary.opacity(0.16))
                        .frame(width: width * 0.28, height: width * 0.025)

                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: width * 0.025)
                            .fill(Color.appSurface.opacity(0.24))
                            .overlay(
                                RoundedRectangle(cornerRadius: width * 0.025)
                                    .stroke(Color.appAccent, lineWidth: 2.2)
                            )

                        VStack(spacing: 0) {
                            GeometryReader { barProxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.appTextSecondary.opacity(0.18))

                                    Capsule()
                                        .fill(Color.appAccent)
                                        .frame(width: barProxy.size.width * progress)
                                }
                            }
                            .frame(height: width * 0.025)
                            .padding(.horizontal, width * 0.04)
                            .padding(.top, width * 0.04)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)

                            Spacer()

                            Image(systemName: "play.rectangle.on.rectangle")
                                .font(.system(size: 37, weight: .semibold))
                                .foregroundColor(.appTextPrimary)
                                .padding(.vertical, 8)

                            Spacer()
                        }

                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(highlightOpacity))
                                .scaleEffect(highlightScale)

                            Image(systemName: "xmark")
                                .font(.system(size: closeSize * 0.48, weight: .bold))
                                .foregroundColor(.appTextPrimary)
                        }
                        .frame(width: closeSize, height: closeSize)
                        .opacity(closeVisibility)
                        .padding(.horizontal, width * 0.055)
                        .padding(.vertical, width * 0.095)
                    }
                    .padding(.horizontal, adInset)
                    .padding(.bottom, width * 0.12)
                }
                .padding(.top, width * 0.08)
            }
        }
    }
}

private struct PreviewAnimationState {
    let progress: Double
    let closeVisibility: Double
    let highlightScale: Double
    let highlightOpacity: Double
}

#Preview {
    AnimatedAdPreviewView()
        .frame(width: 150)
        .padding()
        .background(AppBackgroundGradient())
}
