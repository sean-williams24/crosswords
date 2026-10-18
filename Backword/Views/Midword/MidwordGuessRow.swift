import SwiftUI

struct MidwordGuessRow: View {
    let guess: String
    let isCorrect: Bool
    @ScaledMetric private var cellSize = AppLayout.midwordInputCellSize

    var body: some View {
        letters
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(guess), \(isCorrect ? "correct" : "incorrect")")
            .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    private var letters: some View {
        FittedLetterRow(
            count: guess.count,
            preferredCellSize: cellSize,
            spacing: AppLayout.midwordGuessCellSpacing
        ) { index, fittedCellSize in
            let letter = Array(guess)[index]
            BackwordLetterCell(
                letter: letter,
                isCorrect: isCorrect,
                isFailed: !isCorrect,
                size: fittedCellSize,
                accentColor: .midwordAccent,
                surfaceColor: .midwordBackground,
                textColor: .midwordText,
                correctColor: .midwordAccent
            )
        }
    }
}
