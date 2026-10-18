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
        let width = max(0, width)
        let sizing = LetterRowSizing(
            count: count, availableWidth: width,
            preferredCellSize: AppLayout.anagramTrayPreferredTileSize, spacing: spacing
        )
        let side = sizing.cellSize
        let gap = sizing.spacing
        let rowWidth = CGFloat(count) * side + CGFloat(count - 1) * gap

        return (0..<count).map { index in
            return CGRect(
                x: (width - rowWidth) / 2 + CGFloat(index) * (side + gap),
                y: 0,
                width: side,
                height: side
            )
        }
    }

    private static func preferredWidth(for count: Int, spacing: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * AppLayout.anagramTrayPreferredTileSize
            + CGFloat(count - 1) * max(0, spacing)
    }
}
