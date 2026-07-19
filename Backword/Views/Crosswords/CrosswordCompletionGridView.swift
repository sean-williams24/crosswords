import SwiftUI

struct CrosswordCompletionGridView: View {
    let puzzle: Puzzle
    let style: CrosswordCompletionGridStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealStep = 0
    @State private var isCelebrating = false

    private var isWeekly: Bool { puzzle.size > 12 }

    private var gridWidth: CGFloat {
        isWeekly ? AppLayout.weeklyCompletionGridWidth : AppLayout.dailyCompletionGridWidth
    }

    private var letterSize: CGFloat {
        isWeekly
            ? AppLayout.weeklyCompletionGridLetterSize
            : AppLayout.dailyCompletionGridLetterSize
    }

    private var maximumRevealStep: Int {
        CrosswordCompletionAnimation.maximumRevealStep(cells: puzzle.cells)
    }

    var body: some View {
        ZStack {
            completionGrid
                .scaleEffect(celebrationScale)
                .offset(y: isCelebrating ? -4 : 0)
                .shadow(
                    color: celebrationColor.opacity(isCelebrating ? 0.42 : 0),
                    radius: isCelebrating ? 16 : 0
                )

            if style.showsSparkles {
                CrosswordCompletionSparkleBurstView(isActive: isCelebrating)
            }
        }
        .frame(width: gridWidth, height: gridWidth)
        .task(id: puzzle.id) {
            await runAnimation()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completed crossword grid")
    }

    private var completionGrid: some View {
        let spacing = AppLayout.completionGridSpacing
        let cellSize = (
            gridWidth
                - (spacing * 2)
                - (CGFloat(puzzle.size - 1) * spacing)
        ) / CGFloat(puzzle.size)

        return Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(0..<puzzle.size, id: \.self) { row in
                GridRow {
                    ForEach(0..<puzzle.size, id: \.self) { column in
                        completionCell(
                            puzzle.cells[row][column],
                            row: row,
                            column: column,
                            size: cellSize
                        )
                    }
                }
            }
        }
        .padding(spacing)
        .background(Color.appBackground)
    }

    @ViewBuilder
    private func completionCell(
        _ cell: CellData,
        row: Int,
        column: Int,
        size: CGFloat
    ) -> some View {
        if cell.isBlack {
            Color.appBackground.opacity(0.72)
                .frame(width: size, height: size)
        } else {
            let isRevealed = revealStep >= row + column + 1

            ZStack {
                RoundedRectangle(cornerRadius: AppLayout.cellCornerRadius)
                    .fill(cellBackground(isRevealed: isRevealed))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppLayout.cellCornerRadius)
                            .strokeBorder(cellBorder(isRevealed: isRevealed), lineWidth: 1)
                    }

                if let letter = cell.letter {
                    Text(letter.uppercased())
                        .font(AppFont.gridLetter(letterSize))
                        .foregroundColor(.appTextPrimary)
                        .opacity(isRevealed ? 1 : 0)
                        .scaleEffect(isRevealed ? 1 : 0.55)
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func cellBackground(isRevealed: Bool) -> Color {
        guard isRevealed else { return .appSurface.opacity(0.45) }
        switch style {
        case .solved, .finished:
            return isCelebrating ? .appAccent.opacity(0.2) : .appCorrect.opacity(0.18)
        case .gaveUp:
            return .appGaveUp.opacity(0.18)
        }
    }

    private func cellBorder(isRevealed: Bool) -> Color {
        guard isRevealed else { return .appGridLine.opacity(0.45) }
        switch style {
        case .solved, .finished:
            return isCelebrating ? .appAccent : .appCorrect.opacity(0.78)
        case .gaveUp:
            return .appGaveUp.opacity(0.78)
        }
    }

    private var celebrationColor: Color {
        style == .gaveUp ? .appGaveUp : .appAccent
    }

    private var celebrationScale: CGFloat {
        guard isCelebrating else { return 1 }
        return style == .solved ? 1.055 : 1.025
    }

    @MainActor
    private func runAnimation() async {
        revealStep = reduceMotion ? maximumRevealStep : 0
        isCelebrating = false
        guard !reduceMotion, maximumRevealStep > 0 else { return }

        for step in 1...maximumRevealStep {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: UInt64(CrosswordCompletionAnimation.revealInterval * 1_000_000_000))
            withAnimation(.easeOut(duration: 0.18)) {
                revealStep = step
            }
        }

        guard style.performsBounce, !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: 120_000_000)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.52)) {
            isCelebrating = true
        }
        try? await Task.sleep(nanoseconds: 380_000_000)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
            isCelebrating = false
        }
    }
}

#Preview("Daily solved grid") {
    CrosswordCompletionGridView(puzzle: .sample, style: .solved)
        .padding()
        .background(Color.appBackground)
}

#Preview("Weekly finished grid") {
    CrosswordCompletionGridView(puzzle: .sample13x13, style: .finished)
        .padding()
        .background(Color.appBackground)
}

#Preview("Gave up grid") {
    CrosswordCompletionGridView(puzzle: .sample, style: .gaveUp)
        .padding()
        .background(Color.appBackground)
}
