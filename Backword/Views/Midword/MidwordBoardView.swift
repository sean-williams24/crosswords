import SwiftUI

struct MidwordBoardView: View {
    let puzzle: MidwordPuzzle
    let input: String
    let won: Bool

    @ScaledMetric private var cellSize: CGFloat = 56

    var body: some View {
        VStack(spacing: 18) {
            prompt(puzzle.firstWord)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    guessCells
                        .frame(minWidth: geometry.size.width, alignment: .center)
                }
            }
            .frame(height: cellSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Middle word, \(input.count) of \(puzzle.answer.count) letters entered")
            prompt(puzzle.secondWord)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

    private var guessCells: some View {
        HStack(spacing: 7) {
            ForEach(0..<puzzle.answer.count, id: \.self) { index in
                let letters = Array(won ? puzzle.answer : input)
                BackwordLetterCell(
                    letter: won ? letters[index] : nil,
                    inputLetter: !won && index < letters.count ? letters[index] : nil,
                    isCursor: !won && index == letters.count,
                    isCorrect: won,
                    size: cellSize,
                    accentColor: .midwordAccent,
                    surfaceColor: .midwordBackground,
                    textColor: .midwordText,
                    correctColor: .midwordAccent
                )
            }
        }
    }

    private func prompt(_ word: String) -> some View {
        Text(word)
            .font(AppFont.clueLabel(36))
            .foregroundColor(.midwordText)
            .minimumScaleFactor(0.7)
            .lineLimit(2)
            .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    let puzzle = MidwordPuzzle(
        id: "midword-preview",
        date: "2026-10-01",
        puzzleNumber: 1,
        firstWord: "BANK",
        secondWord: "BOOK",
        answer: "NOTE",
        alternatives: []
    )
    var progress = MidwordProgress(date: puzzle.date)
    MidwordBoardView(puzzle: puzzle, input: "", won: false)
        .padding(.horizontal)
        .background(Color.gray)
}
