import SwiftUI

struct MidwordGuessRow: View {
    let guess: String
    var isCorrect = false
    var guessIndex = 0
    var guessAnimation: Namespace.ID? = nil
    @ScaledMetric private var cellSize = AppLayout.midwordGuessCellSize

    var body: some View {
        FittedLetterRow(
            count: guess.count,
            preferredCellSize: cellSize,
            spacing: AppLayout.midwordGuessCellSpacing
        ) { index, fittedCellSize in
            MidwordAnimatedGuessCell(
                letter: Array(guess)[index], size: fittedCellSize,
                guessIndex: guessIndex, letterIndex: index,
                namespace: guessAnimation
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(guess), \(isCorrect ? "correct" : "incorrect")")
    }
}
