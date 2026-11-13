import SwiftUI

struct MidwordStartView: View {
    let puzzleNumber: Int
    let answerLength: Int
    let onStart: () -> Void

    var body: some View {
        GameStartScreen {
            VStack(spacing: 6) {
                MidwordLogo()
                    .accessibilityLabel("Midword")
                Text("Puzzle #\(puzzleNumber)")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.appTextSecondary)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        } content: {
            TimedGameStartCard(
                heading: "Find the connection.\nComplete both words.",
                explanation: "Find the missing middle word that ends the top word and starts the bottom word. Your clock starts when you press Start and keeps running if you leave the game. Solve in under 30 seconds for five points.",
                detail: "\(answerLength) letters · unlimited guesses · no time limit",
                foreground: .midwordText,
                accent: .midwordAccent,
                surface: .midwordText.opacity(0.08),
                onAccent: .midwordOnAccent,
                onStart: onStart
            )
        }
    }
}
