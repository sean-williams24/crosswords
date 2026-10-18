import SwiftUI

/// Keeps every square cell visible, shrinking cells and gaps together when needed.
struct FittedLetterRow<Cell: View>: View {
    let count: Int
    let preferredCellSize: CGFloat
    let spacing: CGFloat
    var maximumScale: CGFloat = 1
    @ViewBuilder let cell: (Int, CGFloat) -> Cell

    var body: some View {
        GeometryReader { geometry in
            let sizing = LetterRowSizing(
                count: count,
                availableWidth: geometry.size.width,
                preferredCellSize: preferredCellSize,
                spacing: spacing,
                maximumScale: maximumScale
            )
            HStack(spacing: sizing.spacing) {
                ForEach(0..<count, id: \.self) { index in
                    cell(index, sizing.cellSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: preferredCellSize)
    }
}
