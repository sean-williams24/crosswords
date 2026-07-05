import SwiftUI

struct CellView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Scale answer font sizes with Dynamic Type
    @ScaledMetric(relativeTo: .body) private var answerFontSizePhone: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var answerFontSizePhonePro: CGFloat = 13
    @ScaledMetric(relativeTo: .body) private var answerFontSizeIpad: CGFloat = 40
    // Minimum cell sizes that grow with Dynamic Type so cells expand when text is larger
    @ScaledMetric(relativeTo: .body) private var minCellSizeRegular: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var minCellSizePro: CGFloat = 23

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
            .frame(minWidth: minCellSize, minHeight: minCellSize)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectCell(row: row, col: col)
            }
        } else {
            // Black cell — just the background color
            Color.appCrosswordBackground
                .aspectRatio(1, contentMode: .fit)
                .frame(minWidth: minCellSize, minHeight: minCellSize)
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
            AppFont.gridLetter(answerFontSizeIpad)
        } else {
            AppFont.gridLetter(isProPuzzle ? answerFontSizePhonePro : answerFontSizePhone)
        }
    }

    // Only impose a minimum when the user has selected an elevated type size.
    // At the default (.large) type size cells fit the available frame naturally.
    private var minCellSize: CGFloat? {
        guard dynamicTypeSize > .large else { return nil }
        return isProPuzzle ? minCellSizePro : minCellSizeRegular
    }

    // MARK: - Colors

    private var cellBackground: Color {
        if viewModel.isGaveUpRevealed(row: row, col: col) {
            return viewModel.isSelected(row: row, col: col)
                ? .appGaveUp.opacity(0.65)
                : .appGaveUp.opacity(0.3)
        }
        if (settings.crosswordCorrectHighlight || viewModel.hasGivenUp) && viewModel.isCompleted(row: row, col: col) {
            return viewModel.isSelected(row: row, col: col)
                ? .appCorrect.opacity(0.65)
                : .appCorrect.opacity(0.3)
        }
        if viewModel.isSelected(row: row, col: col) {
            return .appAccent
        }
        if viewModel.isInActiveWord(row: row, col: col) {
            return .appAccent.opacity(0.3)
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
