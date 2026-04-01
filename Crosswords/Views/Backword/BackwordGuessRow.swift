import SwiftUI

struct BackwordGuessRow: View {
    let guess: String
    let matchingLetters: Set<Character>
    let showFeedback: Bool
    let isWinningGuess: Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(guess.uppercased().enumerated()), id: \.offset) { index, char in
                chipView(char: char)
            }
        }
    }

    @ViewBuilder
    private func chipView(char: Character) -> some View {
        let isMatch = showFeedback && matchingLetters.contains(char)

        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(chipBackground(isMatch: isMatch))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(chipBorder(isMatch: isMatch), lineWidth: 1)
                )

            Text(String(char))
                .font(AppFont.gridLetter(16))
                .foregroundColor(isWinningGuess ? .appCorrect : .appTextPrimary)
        }
        .frame(width: 38, height: 38)
    }

    private func chipBackground(isMatch: Bool) -> Color {
        if isWinningGuess { return .appCorrect.opacity(0.15) }
        if isMatch { return .appAccent.opacity(0.18) }
        return .appSurface
    }

    private func chipBorder(isMatch: Bool) -> Color {
        if isWinningGuess { return .appCorrect.opacity(0.6) }
        if isMatch { return .appAccent.opacity(0.5) }
        return .appGridLine
    }
}
