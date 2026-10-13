import SwiftUI

struct ProOnlyBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric private var iconSize: CGFloat = 10
    @ScaledMetric private var iconOffset: CGFloat = 1

    private var foreground: Color {
        .homeCardProOnlyForeground(for: colorScheme)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("Pro Only")
                .font(AppFont.clueLabel(10))
                .tracking(0.8)
            Image(systemName: "lock.fill")
                .font(.system(size: iconSize))
                .offset(y: iconOffset)
        }
        .foregroundColor(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(foreground.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .accessibilityElement(children: .combine)
    }
}
