import SwiftUI

/// Measures every card at its column width before assigning one shared height.
struct HomeGameCardsGrid<Content: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        HomeGameCardsGridLayout(spacing: spacing, layoutDirection: layoutDirection) {
            content()
        }
        .environment(\.homeCardFillsProposedHeight, true)
    }
}

struct HomeGameCardsGridLayout: Layout {
    let spacing: CGFloat
    var layoutDirection: LayoutDirection = .leftToRight

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0) * 2 + spacing
        return metrics(width: width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let metrics = metrics(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let column = layoutDirection == .rightToLeft ? 1 - index % 2 : index % 2
            subview.place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(column) * (metrics.cell.width + spacing),
                    y: bounds.minY + CGFloat(index / 2) * (metrics.cell.height + spacing)
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(metrics.cell)
            )
        }
    }

    private func metrics(width: CGFloat, subviews: Subviews) -> (size: CGSize, cell: CGSize) {
        guard !subviews.isEmpty else { return (.zero, .zero) }
        let columnWidth = max(0, (width - spacing) / 2)
        let height = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
        }.max() ?? 0
        let rows = (subviews.count + 1) / 2
        return (
            CGSize(width: width, height: CGFloat(rows) * height + CGFloat(rows - 1) * spacing),
            CGSize(width: columnWidth, height: height)
        )
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
