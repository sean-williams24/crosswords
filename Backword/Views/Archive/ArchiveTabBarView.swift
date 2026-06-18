import SwiftUI

struct ArchiveTabBarItemContent: Equatable {
    let title: String
    let accessibilityLabel: String

    static func content(for tab: ArchiveTab) -> ArchiveTabBarItemContent {
        switch tab {
        case .backword:
            return ArchiveTabBarItemContent(
                title: "Backword",
                accessibilityLabel: "Backword archive"
            )
        case .daily:
            return ArchiveTabBarItemContent(
                title: "Daily",
                accessibilityLabel: "Daily crossword archive"
            )
        case .weekly:
            return ArchiveTabBarItemContent(
                title: "Pro",
                accessibilityLabel: "Pro crossword archive"
            )
        }
    }
}

struct ArchiveTabBarView: View {
    let tabs: [ArchiveTab]
    let selectedTab: ArchiveTab
    let selectTab: (ArchiveTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let content = ArchiveTabBarItemContent.content(for: tab)

                Button {
                    selectTab(tab)
                } label: {
                    Text(content.title)
                        .font(AppFont.clueLabel(selectedTab == tab ? 13 : 11))
                        .foregroundStyle(selectedTab == tab ? Color.appTextPrimary : Color.appTextSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.appAccent.opacity(0.14))
                                    .padding(6)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(content.accessibilityLabel)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .frame(width: 330, height: 54)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background { tabBarBackground }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
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
        ArchiveTabBarView(
            tabs: ArchiveTab.allCases,
            selectedTab: .daily,
            selectTab: { _ in }
        )
    }
}
