import SwiftUI

struct HomeTabBarItemContent: Equatable {
    let title: String
    let systemImage: String
    let accessibilityLabel: String

    static func archive(isProUser: Bool) -> HomeTabBarItemContent {
        HomeTabBarItemContent(
            title: "Archive",
            systemImage: isProUser ? "archivebox" : "lock.fill",
            accessibilityLabel: isProUser ? "Archive" : "Archive, Go Pro required"
        )
    }

    static let stats = HomeTabBarItemContent(
        title: "Stats",
        systemImage: "brain.head.profile",
        accessibilityLabel: "Stats"
    )
}

struct HomeTabBarView: View {
    let isProUser: Bool
    let showArchive: () -> Void
    let showStats: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(content: .archive(isProUser: isProUser), action: showArchive)
                tabButton(content: .stats, action: showStats)
            }
            .frame(width: 260, height: 62)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .background { tabBarBackground }
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func tabButton(content: HomeTabBarItemContent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: content.systemImage)
                    .font(.system(size: 20, weight: .light))

                Text(content.title)
                    .font(AppFont.clueLabel(11))
            }
            .foregroundStyle(Color.appTextPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(content.accessibilityLabel)
    }

    @ViewBuilder
    private var tabBarBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(Color.appBackground.opacity(0.16))
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(Color.appBackground.opacity(0.75))
                }
        }
    }
}

#Preview {
    ZStack {
        AppBackgroundGradient()
        HomeTabBarView(
            isProUser: true,
            showArchive: {},
            showStats: {}
        )
    }
}
