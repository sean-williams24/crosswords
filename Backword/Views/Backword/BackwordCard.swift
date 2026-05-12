import SwiftUI

struct BackwordCard: View {
    @ScaledMetric private var spacing: CGFloat = 10
    let word: BackwordWord?
    let progress: BackwordProgress?

    var body: some View {
        VStack(alignment: .center, spacing: spacing) {
                BackwordLogo()

            if let progress, progress.isComplete {
                completionContent(progress: progress)
            } else {
                Group {
                    if let word {
                        HStack(spacing: 6) {
                            let revealedCount = progress?.revealedCount ?? 1
                            let revealed = BackwordViewModel.revealedIndices(forRevealedCount: revealedCount)
                            let letters = Array(word.word)
                            ForEach(0..<6, id: \.self) { i in
                                BackwordLetterCell(
                                    letter: revealed.contains(i) ? letters[i] : nil,
                                    size: 34
                                )
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .frame(height: 34)
                    }
                }

                // Always show the caption text
                if let progress, !progress.guesses.isEmpty {
                    Text("\(progress.guesses.count) / 5 guesses")
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                } else {
                    Text("Guess the 6-letter word")
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                        .padding(.bottom, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 144)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .strokeBorder(Color.appAccent, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func completionContent(progress: BackwordProgress) -> some View {
        HStack(spacing: 8) {
            Image(systemName: progress.wonFlag ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(progress.wonFlag ? .appCorrect : .red.opacity(0.7))
                .font(.system(size: 16))

            if progress.wonFlag {
                Text("Completed in \(progress.guesses.count) guess\(progress.guesses.count == 1 ? "" : "es")")
                    .font(AppFont.body(14))
                    .foregroundColor(.appTextSecondary)
            } else {
                Text("Better luck tomorrow")
                    .font(AppFont.body(14))
                    .foregroundColor(.appTextSecondary)
            }
        }
    }
}

#Preview {
    VStack {
        BackwordCard(
            word: BackwordWord(
                date: "",
                word: "Seannnn",
                category: "",
                definition: ""
            ),
            progress: nil
        )

        BackwordCard(
            word: nil,
            progress: nil
        )
    }
}
