import SwiftUI

struct PuzzleGridView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        let size = viewModel.puzzle.size
        let spacing = AppLayout.gridSpacing

        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(0..<size, id: \.self) { row in
                GridRow {
                    ForEach(0..<size, id: \.self) { col in
                        CellView(row: row, col: col, viewModel: viewModel)
                    }
                }
            }
        }
        .padding(spacing)
        .background(Color.appBackground)
        .cornerRadius(AppLayout.cardCornerRadius)
    }
}
