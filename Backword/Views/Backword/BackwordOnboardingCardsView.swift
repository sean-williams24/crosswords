import SwiftUI

struct BackwordOnboardingCardsView: View {
    let steps: [BackwordOnboardingStep]
    let mode: BackwordMode
    let dismissStep: (BackwordOnboardingStep) -> Void

    @State private var hasEntered = false
    @ScaledMetric private var cardOffset: CGFloat = 16

    var body: some View {
        ZStack(alignment: .top) {
            if hasEntered {
                ForEach(Array(steps.enumerated().reversed()), id: \.element.id) { index, step in
                    BackwordOnboardingCard(
                        text: step.text(for: mode),
                        dismiss: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                dismissStep(step)
                            }
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.96)),
                            removal: .move(edge: .top)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.96))
                        )
                    )
                    .offset(y: CGFloat(index) * cardOffset)
                    .opacity(cardOpacity(for: index))
                    .scaleEffect(cardScale(for: index), anchor: .top)
                    .zIndex(Double(steps.count - index))
                    .allowsHitTesting(index == 0)
                    .accessibilityHidden(index != 0)
                    .animation(
                        .spring(response: 0.55, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                        value: steps
                    )
                }
            }
        }
        .padding(.bottom, CGFloat(max(steps.count - 1, 0)) * cardOffset)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 8)
        .onAppear {
            guard !steps.isEmpty else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                hasEntered = true
            }
        }
    }

    private func cardOpacity(for index: Int) -> Double {
        max(0.22, 1 - Double(index) * 0.18)
    }

    private func cardScale(for index: Int) -> CGFloat {
        max(0.92, 1 - CGFloat(index) * 0.02)
    }
}

private struct BackwordOnboardingCard: View {
    let text: String
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isHovering = false
    @ScaledMetric private var cardHeight: CGFloat = 80

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(text)
                .font(AppFont.body(13))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(action: dismiss) {
                Text("OK")
                    .font(AppFont.clueLabel(12))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.appAccent)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Dismiss instruction")
            .accessibilityHint("Dismisses this Backword instruction")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(
            maxWidth: .infinity,
            minHeight: cardHeight,
            maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : cardHeight,
            alignment: .leading
        )
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .strokeBorder(Color.appGridLine, lineWidth: 1)
        }
        .shadow(color: Color.appTextPrimary.opacity(0.12), radius: 8, y: 4)
        .offset(y: isHovering ? -2 : 2)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isHovering = true
            }
        }
    }
}

#Preview {
    BackwordOnboardingCardsView(
        steps: BackwordOnboardingStep.allCases,
        mode: .easy,
        dismissStep: { _ in }
    )
    .padding()
    .background(Color.appBackground)
}
