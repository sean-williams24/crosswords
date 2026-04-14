import SwiftUI

struct MiniGridPattern: View {
    private let gridSize = 7
    private let cellSize: CGFloat = 18
    private let spacing: CGFloat = 2

    // Asymmetric crossword-style black cell positions
    private let blackCells: Set<Int> = [
        2, 9, 15, 20, 26, 33, 39, 44
    ]

    var body: some View {
        GeometryReader { geo in
            let totalCellSize = cellSize + spacing
            let cols = Int(geo.size.width / totalCellSize) + 2
            let rows = Int(geo.size.height / totalCellSize) + 2

            Canvas { context, _ in
                for row in 0..<rows {
                    for col in 0..<cols {
                        let wrappedRow = row % gridSize
                        let wrappedCol = col % gridSize
                        let index = wrappedRow * gridSize + wrappedCol
                        let isBlack = blackCells.contains(index)

                        let rect = CGRect(
                            x: CGFloat(col) * totalCellSize,
                            y: CGFloat(row) * totalCellSize,
                            width: cellSize,
                            height: cellSize
                        )

                        if isBlack {
                            context.fill(
                                Path(roundedRect: rect, cornerRadius: 2),
                                with: .color(.appTextPrimary)
                            )
                        } else {
                            context.stroke(
                                Path(roundedRect: rect, cornerRadius: 2),
                                with: .color(.appTextPrimary),
                                lineWidth: 0.5
                            )
                        }
                    }
                }
            }
        }
    }
}
