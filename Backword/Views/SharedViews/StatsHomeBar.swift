import SwiftUI

struct StatsHomeBar: View {
    var foregroundColor: Color = .appTextSecondary
    var backgroundColor: Color = .appBackground
    let onBackToGame: () -> Void
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            if let action {
                footerButton("HOME", accessibilityLabel: "Home", action: action)
            }
            footerButton("BACK TO GAME", accessibilityLabel: "Back to game", action: onBackToGame)
        }
        .fixedSize(horizontal: false, vertical: true)
        .buttonStyle(.plain)
        .background { glassBackground }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, AppLayout.statsHomeBarVerticalPadding)
    }

    private func footerButton(_ title: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body())
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppLayout.statsHomeButtonHorizontalPadding)
                .padding(.vertical, AppLayout.statsHomeButtonVerticalPadding)
                .frame(maxWidth: .infinity, minHeight: AppLayout.minimumTouchTarget, maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(backgroundColor.opacity(0.16))
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
        }
    }
}
