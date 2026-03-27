import SwiftUI

struct CellView: View {
    let row: Int
    let col: Int
    @ObservedObject var viewModel: GameViewModel

    private var cell: CellData? {
        viewModel.cellData(row: row, col: col)
    }

    var body: some View {
        if let cell, !cell.isBlack {
            ZStack(alignment: .topLeading) {
                // Background
                cellBackground
                    .cornerRadius(AppLayout.cellCornerRadius)

                // Clue number
                if let number = cell.clueNumber {
                    Text("\(number)")
                        .font(AppFont.clueNumber())
                        .foregroundColor(.appTextSecondary)
                        .padding(.leading, 2)
                        .padding(.top, 1)
                }

                // Letter
                if let letter = viewModel.enteredLetter(row: row, col: col) {
                    Text(String(letter))
                        .font(viewModel.answerFont)
                        .foregroundColor(letterColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectCell(row: row, col: col)
            }
        } else {
            // Black cell — just the background color
            Color.appBackground
                .aspectRatio(1, contentMode: .fit)
        }
    }

    // MARK: - Colors

    private var cellBackground: Color {
        if viewModel.isRecentlyCompleted(row: row, col: col) {
            return .appCorrect.opacity(0.3)
        }
        if viewModel.isSelected(row: row, col: col) {
            return .appAccent
        }
        if viewModel.isInActiveWord(row: row, col: col) {
            return .appAccent.opacity(0.1)
        }
        return .appSurface
    }

    private var letterColor: Color {
        if viewModel.isSelected(row: row, col: col) {
            return .white
        }
        return .appTextPrimary
    }
}
