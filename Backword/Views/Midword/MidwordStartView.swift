import SwiftUI

struct MidwordStartView: View {
    let answerLength: Int
    let onStart: () -> Void

    var body: some View {
        GameStartContainer {
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
