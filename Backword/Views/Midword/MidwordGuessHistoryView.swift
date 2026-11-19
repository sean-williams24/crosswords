import SwiftUI

struct MidwordGuessHistoryView: View {
    let guesses: [String]
    let indices: [Int]
    let guessAnimation: Namespace.ID?

    var body: some View {
        if !indices.isEmpty {
            VStack(spacing: AppLayout.midwordGuessHistorySpacing) {
                Text("Previous Guesses")
                    .font(AppFont.caption(16))
                    .foregroundStyle(Color.midwordText.opacity(0.7))
                ForEach(indices, id: \.self) { index in
                    MidwordGuessRow(
                        guess: guesses[index], guessIndex: index,
                        guessAnimation: guessAnimation
                    )
                    .transition(.identity)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
