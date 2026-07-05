import SwiftUI

struct AdFreeExperienceButtonContent: Equatable {
    let title: String
    let detail: String
    let subtitle: String
    let systemImage: String

    var accessibilityLabel: String {
        "\(title), \(detail), \(subtitle)"
    }

    static let home = AdFreeExperienceButtonContent(
        title: "Ad-free experience",
        detail: "Archive access",
        subtitle: "Go Pro",
        systemImage: "sparkles"
    )
}

struct AdFreeExperienceButtonVisibility {
    static func shouldShow(isProUser: Bool, subscriptionStatusLoaded: Bool) -> Bool {
        subscriptionStatusLoaded && !isProUser
    }
}

struct AdFreeExperienceButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 16
        static let cardHeight: CGFloat = 72
    }

    let content: AdFreeExperienceButtonContent
    let height: CGFloat
    let showDetails: Bool
    let action: () -> Void

    init(
        content: AdFreeExperienceButtonContent = .home,
        height: CGFloat = Layout.cardHeight,
        showDetails: Bool = true,
        action: @escaping () -> Void
    ) {
        self.content = content
        self.height = height
        self.showDetails = showDetails
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: content.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(proGradient)
                    .frame(width: 28, height: 28)
                    .background(Color.appSurface.opacity(0.26))
                    .clipShape(Circle())
                    .scaleEffect(isAnimating && !reduceMotion ? 1.12 : 1)
                    .rotationEffect(.degrees(isAnimating && !reduceMotion ? 8 : -6))

                VStack(alignment: .leading, spacing: 3) {
                    Text(content.title)
                        .font(AppFont.clueLabel(13))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .allowsTightening(true)

                    if showDetails {
                        Text(content.detail)
                            .font(AppFont.caption(12))
                            .foregroundColor(.appTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .allowsTightening(true)
                    }
                }
                .layoutPriority(2)

                Spacer(minLength: 6)

                Text(content.subtitle)
                    .font(AppFont.clueLabel(10))
                    .foregroundColor(.appAccent)
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
                    .fixedSize(horizontal: true, vertical: false)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .scaleEffect(isAnimating && !reduceMotion ? 1.04 : 0.98)
                    .opacity(isAnimating && !reduceMotion ? 1 : 0.82)
                    .layoutPriority(1)

                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                    .fill(Color.appSurface.opacity(0.26))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                            .stroke(proGradient, lineWidth: 0)
                    )
                    .shadow(color: Color.appAccent.opacity(0.16), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(content.accessibilityLabel)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 1.35)
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            if shouldReduceMotion {
                isAnimating = false
            } else {
                withAnimation(
                    .easeInOut(duration: 1.35)
                        .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
        }
    }

    private var proGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.appTextPrimary,
                Color.appAccent,
                Color.dailyCardTitle
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    AdFreeExperienceButton(action: {})
        .padding()
        .background(AppBackgroundGradient())
}
