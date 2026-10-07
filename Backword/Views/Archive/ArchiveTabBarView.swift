import SwiftUI

enum ArchiveTabBarLayout: Equatable {
    case singleRow
    case twoRowGrid

    static func layout(for dynamicTypeSize: DynamicTypeSize) -> ArchiveTabBarLayout {
        dynamicTypeSize.isAccessibilitySize ? .twoRowGrid : .singleRow
    }

    var height: CGFloat {
        switch self {
        case .singleRow:
            return 54
        case .twoRowGrid:
            return 108
        }
    }

    var archiveContentBottomPadding: CGFloat {
        height + 58
    }

    var containerCornerRadius: CGFloat {
        25
    }

    static let minimumTitleScaleFactor: CGFloat = 0.75

    static func rows(for tabs: [ArchiveTab], columnCount: Int = 3) -> [[ArchiveTab]] {
        guard columnCount > 0 else { return [] }

        return stride(from: 0, to: tabs.count, by: columnCount).map { startIndex in
            Array(tabs[startIndex..<min(startIndex + columnCount, tabs.count)])
        }
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
        case .midword:
            return ArchiveTabBarItemContent(
                title: "Midword",
                accessibilityLabel: "Midword archive"
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
            if layout == .twoRowGrid {
                VStack(spacing: 0) {
                    ForEach(Array(tabRows.enumerated()), id: \.offset) { _, row in
                        evenlySpacedTabRow(row)
                    }
                }
            } else {
                evenlySpacedTabRow(tabs)
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

    private var tabRows: [[ArchiveTab]] {
        ArchiveTabBarLayout.rows(for: tabs)
    }

    private func evenlySpacedTabRow(_ rowTabs: [ArchiveTab]) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ForEach(rowTabs, id: \.self) { tab in
                tabButton(for: tab)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 54)
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
                .minimumScaleFactor(ArchiveTabBarLayout.minimumTitleScaleFactor)
                .allowsTightening(true)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .frame(minHeight: 44)
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
