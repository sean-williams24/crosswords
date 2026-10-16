import SwiftUI

struct SettingsAccountRowContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let detail: String
    let systemImage: String
    let iconColumnWidth: CGFloat

    var body: some View {
        Group {
            if SettingsAccountRowLayout.stacksVertically(for: dynamicTypeSize) {
                VStack(alignment: .leading, spacing: AppLayout.settingsAccountRowSpacing) {
                    accountText
                    HStack {
                        accountIcon
                        Spacer()
                        chevron
                    }
                }
            } else {
                HStack(spacing: AppLayout.settingsAccountRowSpacing) {
                    accountIcon
                    accountText
                    Spacer()
                    chevron
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var accountText: some View {
        VStack(alignment: .leading, spacing: AppLayout.settingsAccountTextSpacing) {
            Text(title)
                .font(AppFont.body(AppLayout.settingsAccountTitleSize))
                .foregroundColor(.appTextPrimary)
            Text(detail)
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var accountIcon: some View {
        Image(systemName: systemImage)
            .font(AppFont.settingsAccountIcon)
            .foregroundColor(.appAccent)
            .frame(width: iconColumnWidth)
            .accessibilityHidden(true)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(AppFont.settingsRowChevron)
            .foregroundColor(.appTextSecondary)
            .accessibilityHidden(true)
    }
}

enum SettingsAccountRowLayout {
    static func stacksVertically(for dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize.isAccessibilitySize
    }
}
