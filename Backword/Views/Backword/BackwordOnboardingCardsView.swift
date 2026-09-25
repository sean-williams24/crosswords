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
                        isTopCard: index == 0,
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
                            removal: .move(edge: .leading)
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
        .padding(.top, 20)
        .padding(.vertical, 8)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
    let isTopCard: Bool
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isHovering = false
    @State private var isOKButtonPulsing = false
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
            .buttonStyle(
                BackwordOnboardingOKButtonStyle(
                    isPulsing: isOKButtonPulsing,
                    reduceMotion: reduceMotion
                )
            )
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
        .shadow(color: Color.appTextPrimary.opacity(0.08), radius: 6, y: 3)
        .offset(y: isHovering ? -2 : 2)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isHovering = true
            }
            animateOKButtonIfNeeded()
        }
        .onChange(of: isTopCard) { _ in
            animateOKButtonIfNeeded()
        }
    }

    private func animateOKButtonIfNeeded() {
        guard isTopCard, !reduceMotion else {
            isOKButtonPulsing = false
            return
        }

        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            isOKButtonPulsing = true
        }
    }
}

private struct BackwordOnboardingOKButtonStyle: ButtonStyle {
    let isPulsing: Bool
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : (isPulsing ? 1.07 : 1))
            .shadow(
                color: Color.appAccent.opacity(isPulsing ? 0.38 : 0.18),
                radius: isPulsing ? 6 : 2
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.15),
                value: configuration.isPressed
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.85).repeatForever(autoreverses: true),
                value: isPulsing
            )
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
