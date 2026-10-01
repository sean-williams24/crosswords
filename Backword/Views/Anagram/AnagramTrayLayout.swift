import SwiftUI

struct AnagramTrayLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil }
            ?? Self.preferredWidth(for: subviews.count, spacing: spacing)
        let frames = Self.tileFrames(count: subviews.count, width: width, spacing: spacing)
        return CGSize(width: width, height: frames.last?.maxY ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = Self.tileFrames(count: subviews.count, width: bounds.width, spacing: spacing)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    static func tileFrames(count: Int, width: CGFloat, spacing: CGFloat) -> [CGRect] {
        guard count > 0 else { return [] }
        let firstRowCount = (count + 1) / 2
        let secondRowCount = count - firstRowCount
        let sizingColumns = max(firstRowCount, AppLayout.anagramTraySizingColumns)
        let width = max(0, width)
        let gap = min(max(0, spacing), width / CGFloat(max(1, sizingColumns - 1)))
        let side = (width - CGFloat(sizingColumns - 1) * gap) / CGFloat(sizingColumns)

        return (0..<count).map { index in
            let isFirstRow = index < firstRowCount
            let rowCount = isFirstRow ? firstRowCount : secondRowCount
            let column = isFirstRow ? index : index - firstRowCount
            let rowWidth = CGFloat(rowCount) * side + CGFloat(rowCount - 1) * gap
            return CGRect(
                x: (width - rowWidth) / 2 + CGFloat(column) * (side + gap),
                y: isFirstRow ? 0 : side + gap,
                width: side,
                height: side
            )
        }
    }

    private static func preferredWidth(for count: Int, spacing: CGFloat) -> CGFloat {
        let columns = max((count + 1) / 2, AppLayout.anagramTraySizingColumns)
        guard columns > 0 else { return 0 }
        return CGFloat(columns) * AppLayout.anagramTrayPreferredTileSize
            + CGFloat(columns - 1) * spacing
    }
}
