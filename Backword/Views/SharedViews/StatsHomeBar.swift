import SwiftUI

struct StatsHomeBar: View {
    var foregroundColor: Color = .appTextSecondary
    var backgroundColor: Color = .appBackground
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("HOME")
                .font(AppFont.body())
                .foregroundStyle(foregroundColor)
                .padding(.vertical, AppLayout.statsHomeButtonVerticalPadding)
                .frame(maxWidth: .infinity, minHeight: AppLayout.minimumTouchTarget, alignment: .center)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background { glassBackground }
        .accessibilityLabel("Home")
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, AppLayout.statsHomeBarVerticalPadding)
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
