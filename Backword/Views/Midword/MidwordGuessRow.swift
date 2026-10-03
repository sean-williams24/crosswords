import SwiftUI

struct MidwordGuessRow: View {
    let guess: String
    let isCorrect: Bool
    @ScaledMetric private var cellSize: CGFloat = 56

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                letters
                    .frame(minWidth: geometry.size.width, alignment: .center)
            }
        }
        .frame(height: cellSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(guess), \(isCorrect ? "correct" : "incorrect")")
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    private var letters: some View {
        HStack(spacing: 6) {
            ForEach(Array(guess.enumerated()), id: \.offset) { _, letter in
                BackwordLetterCell(
                    letter: letter,
                    isCorrect: isCorrect,
                    isFailed: !isCorrect,
                    size: cellSize,
                    accentColor: .midwordAccent,
                    surfaceColor: .midwordBackground,
                    textColor: .midwordText,
                    correctColor: .midwordAccent
                )
            }
        }
    }
}
