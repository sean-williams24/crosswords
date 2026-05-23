//  BackwordInstructionsContentView.swift

import SwiftUI

struct BackwordInstructionsContentView: View {
    @ScaledMetric private var iconFrame: CGFloat = 20
    @ScaledMetric private var cellFrame: CGFloat = 36

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    instructionRow(number: "1", text: "Guess the 6-letter word in 5 tries.")
                    instructionRow(number: "2", text: "Type the missing letters into the highlighted cells, then tap Submit.")
                    instructionRow(number: "3", text: "After each wrong guess, any letters you got right at the end of the word are revealed.")
                    instructionRow(number: "4", text: "Unmatched letters from previous guesses are not eliminated — they're still in play")

                    instructionRow(number: "5", text: "The clue is shown at the top — use it to guide your guess.")
                    instructionRow(number: "6", text: "The fewer the guesses, the more points you get.")
                }

                Divider()
                    .background(Color.appGridLine)

                HStack(spacing: 12) {
                    exampleCell(letter: "C", isRevealed: false)
                    exampleCell(letter: "A", isRevealed: false)
                    exampleCell(letter: "S", isRevealed: false)
                    exampleCell(letter: "T", isRevealed: true)
                    exampleCell(letter: "L", isRevealed: true)
                    exampleCell(letter: "E", isRevealed: true)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Text("After 2 wrong guesses — 3 letters revealed")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                ScoringRuleView.backword()

            }
            .padding(20)
        }
        .background(Color.appBackground)
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(AppFont.clueLabel(13))
                .foregroundColor(.white)
                .frame(width: iconFrame, height: iconFrame)
                .background(Color.appAccent)
                .clipShape(Circle())
            Text(text)
                .font(AppFont.body(14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func exampleCell(letter: String, isRevealed: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isRevealed ? Color.appAccent.opacity(0.5) : Color.appGridLine,
                            lineWidth: 1.5
                        )
                )
            Text(isRevealed ? letter : "")
                .font(AppFont.gridLetter(16))
                .foregroundColor(.appTextPrimary)
        }
        .frame(width: 36, height: 36)
    }
}

#Preview {
    BackwordInstructionsContentView()
}
