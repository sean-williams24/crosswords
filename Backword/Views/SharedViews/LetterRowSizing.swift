import CoreGraphics

struct LetterRowSizing {
    let cellSize: CGFloat
    let spacing: CGFloat

    init(count: Int, availableWidth: CGFloat, preferredCellSize: CGFloat, spacing: CGFloat, maximumScale: CGFloat = 1) {
        let preferredCellSize = max(0, preferredCellSize)
        let spacing = max(0, spacing)
        let preferredWidth = CGFloat(max(0, count)) * preferredCellSize
            + CGFloat(max(0, count - 1)) * spacing
        guard count > 0, preferredWidth > 0 else {
            self.cellSize = 0
            self.spacing = 0
            return
        }

        // Reserve width for any celebration animation before fitting the row.
        let width = max(0, availableWidth) / max(1, maximumScale)
        let fitScale = min(1, width / preferredWidth)
        self.cellSize = preferredCellSize * fitScale
        self.spacing = spacing * fitScale
    }
}
