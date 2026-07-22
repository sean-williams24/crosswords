//  BackwordInstructionsContentView.swift

import SwiftUI

struct BackwordInstructionsContentView: View {
    @ScaledMetric private var iconFrame: CGFloat = 20
    @ScaledMetric private var cellFrame: CGFloat = 36

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    instructionRow(number: "1", text: "Guess the six-letter word, starting with the final letter revealed.")
                    instructionRow(number: "2", text: "Correctly placed letters only reveal when they form an unbroken chain from the end of the word.")
                    instructionRow(number: "3", text: "If the word is still unsolved after three guesses, the third letter reveals as an extra hint.")
                    instructionRow(number: "4", text: "The fewer guesses you need, the more points you score.")
                    instructionRow(number: nil, text: "Apart from the extra hint, a correct letter elsewhere stays hidden until it connects to the revealed ending. A guess may reveal no new letters.")
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

                Text("A guess ending in TLE reveals the connected suffix")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                ScoringRuleView.backword(title: "Scoring")

            }
            .padding(20)
        }
        .background(Color.appBackground)
    }

    private func instructionRow(number: String?, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let number {
                Text(number)
                    .font(AppFont.clueLabel(13))
                    .foregroundColor(.white)
                    .frame(width: iconFrame, height: iconFrame)
                    .background(Color.appAccent)
                    .clipShape(Circle())
            } else {
                Image(systemName: "info.circle")
                    .foregroundColor(.appCorrect)
            }
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
