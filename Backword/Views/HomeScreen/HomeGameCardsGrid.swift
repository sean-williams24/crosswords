import SwiftUI

/// Measures every card at its column width before assigning one shared height.
struct HomeGameCardsGrid<Content: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection
    var columns = 2
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        HomeGameCardsGridLayout(columns: columns, spacing: spacing, layoutDirection: layoutDirection) {
            content()
        }
        .environment(\.homeCardFillsProposedHeight, true)
    }
}

struct HomeGameCardsGridLayout: Layout {
    /// Interspersed upsells keep their own height and do not affect game sizing.
    struct IntrinsicHeightKey: LayoutValueKey {
        static let defaultValue = false
    }

    var columns = 2
    let spacing: CGFloat
    var layoutDirection: LayoutDirection = .leftToRight

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0)
            * CGFloat(columns) + CGFloat(columns - 1) * spacing
        let metrics = metrics(width: width, subviews: subviews)
        return CGSize(
            width: subviews.isEmpty ? 0 : width,
            height: metrics.rowHeights.reduce(0, +) + CGFloat(max(0, metrics.rowHeights.count - 1)) * spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let metrics = metrics(width: bounds.width, subviews: subviews)
        var rowY = bounds.minY
        for (index, subview) in subviews.enumerated() {
            let row = index / columns
            let column = layoutDirection == .rightToLeft ? columns - 1 - index % columns : index % columns
            subview.place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(column) * (metrics.columnWidth + spacing),
                    y: rowY
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: metrics.columnWidth, height: metrics.rowHeights[row])
            )
            if index % columns == columns - 1 {
                rowY += metrics.rowHeights[row] + spacing
            }
        }
    }

    private func metrics(width: CGFloat, subviews: Subviews) -> (columnWidth: CGFloat, rowHeights: [CGFloat]) {
        let columnWidth = max(0, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        let heights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
        }
        let sharedHeight = subviews.indices
            .filter { !subviews[$0][IntrinsicHeightKey.self] }
            .map { heights[$0] }.max() ?? 0
        var rowHeights = Array(repeating: CGFloat.zero, count: (subviews.count + columns - 1) / columns)
        for index in subviews.indices {
            let height = subviews[index][IntrinsicHeightKey.self] ? heights[index] : sharedHeight
            rowHeights[index / columns] = max(rowHeights[index / columns], height)
        }
        return (columnWidth, rowHeights)
    }
}

private struct HomeCardFillsProposedHeightKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var homeCardFillsProposedHeight: Bool {
        get { self[HomeCardFillsProposedHeightKey.self] }
        set { self[HomeCardFillsProposedHeightKey.self] = newValue }
    }
}
