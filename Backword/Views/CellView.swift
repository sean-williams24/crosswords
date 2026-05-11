import SwiftUI

struct CellView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    let row: Int
    let col: Int
    @ObservedObject var viewModel: GameViewModel
    private let settings = AppSettings.shared

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
                        .font(clueFont)
                        .foregroundColor(.appTextSecondary)
                        .padding(.leading, isProPuzzle ? 1 : 2)
                        .padding(.top, isProPuzzle ? 0 : 1)
                }

                // Letter
                if let letter = viewModel.enteredLetter(row: row, col: col) {
                    Text(String(letter))
                        .font(answerFont)
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

    private var isIpad: Bool {
        sizeClass == .regular
    }

    private var isProPuzzle: Bool {
        viewModel.puzzle.size > 12
    }

    var clueFont: Font {
        if isIpad {
            AppFont.clueNumber(isProPuzzle ? 13 : 20)
        } else {
            AppFont.clueNumber(isProPuzzle ? 6 : 8)
        }
    }

    var answerFont: Font {
        if isIpad {
            AppFont.gridLetter(isProPuzzle ? 40 : 60)
        } else {
            AppFont.gridLetter(isProPuzzle ? 13 : 18)
        }
    }

    // MARK: - Colors

    private var cellBackground: Color {
        if settings.crosswordCorrectHighlight && viewModel.isRecentlyCompleted(row: row, col: col) {
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

#Preview {
    CellView(
        row: 1,
        col: 4,
        viewModel: GameViewModel(puzzle: .sample)
    )
    .frame(width: 60, height: 60)
    .padding()
}
