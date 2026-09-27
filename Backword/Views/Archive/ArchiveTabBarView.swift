import SwiftUI

enum ArchiveTabBarLayout: Equatable {
    case singleRow
    case twoByTwo

    static func layout(for dynamicTypeSize: DynamicTypeSize) -> ArchiveTabBarLayout {
        dynamicTypeSize > .large ? .twoByTwo : .singleRow
    }

    var height: CGFloat {
        switch self {
        case .singleRow:
            return 54
        case .twoByTwo:
            return 108
        }
    }

    var archiveContentBottomPadding: CGFloat {
        height + 58
    }

    var containerCornerRadius: CGFloat {
        25
    }
}

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
                title: "Quick",
                accessibilityLabel: "Quick crossword archive"
            )
        case .anagram:
            return ArchiveTabBarItemContent(
                title: "Anagram",
                accessibilityLabel: "Anagram archive"
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let tabs: [ArchiveTab]
    let selectedTab: ArchiveTab
    let selectTab: (ArchiveTab) -> Void

    var body: some View {
        Group {
            if layout == .twoByTwo {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 2),
                    spacing: 0
                ) {
                    tabButtons
                }
            } else {
                HStack(spacing: 0) {
                    tabButtons
                }
            }
        }
        .frame(maxWidth: 420)
        .frame(height: layout.height)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .background { tabBarBackground }
        .clipShape(containerShape)
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var layout: ArchiveTabBarLayout {
        ArchiveTabBarLayout.layout(for: dynamicTypeSize)
    }

    private var containerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: layout.containerCornerRadius, style: .continuous)
    }

    @ViewBuilder
    private var tabButtons: some View {
        ForEach(tabs, id: \.self) { tab in
            tabButton(for: tab)
                .frame(height: 54)
        }
    }

    private func tabButton(for tab: ArchiveTab) -> some View {
        let content = ArchiveTabBarItemContent.content(for: tab)

        return Button {
            selectTab(tab)
        } label: {
            Text(content.title)
                .font(AppFont.clueLabel(selectedTab == tab ? 13 : 11))
                .foregroundStyle(selectedTab == tab ? Color.appTextPrimary : Color.appTextSecondary)
                .lineLimit(1)
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

    @ViewBuilder
    private var tabBarBackground: some View {
        if #available(iOS 26.0, *) {
            containerShape
                .fill(Color.appBackground.opacity(0.16))
                .glassEffect(.regular.interactive(), in: containerShape)
        } else {
            containerShape
                .fill(.ultraThinMaterial)
                .overlay {
                    containerShape
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
