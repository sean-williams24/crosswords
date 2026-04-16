import SwiftUI

struct BackwordCard: View {
    let word: BackwordWord?
    let progress: BackwordProgress?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: -7) {
                Text("Daily")
                    .font(AppFont.clueLabel(11))
                    .foregroundColor(.appTextPrimary)
                    .tracking(3)
                    .offset(y: 5)
                    .italic()

                BackwordLogo()
            }

            if let progress, progress.isComplete {
                completionContent(progress: progress)
            } else if let word {
                inProgressContent(word: word, progress: progress)
            } else {
                ProgressView()
                    .tint(.appAccent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(AppLayout.cardCornerRadius)
        .padding(.horizontal, AppLayout.screenPadding)
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
                Text("Better luck tomorrow!")
                    .font(AppFont.body(14))
                    .foregroundColor(.appTextSecondary)
            }
        }
    }

    @ViewBuilder
    private func inProgressContent(word: BackwordWord, progress: BackwordProgress?) -> some View {
        // Show the currently revealed letters as a small teaser row
        let revealedCount = progress?.revealedCount ?? 1
        let letters = Array(word.word)

        HStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { i in
                BackwordLetterCell(
                    letter: i >= (6 - revealedCount) ? letters[i] : nil,
                    size: 34
                )
            }
        }

        if let progress, !progress.guesses.isEmpty {
            Text("\(progress.guesses.count) / 5 guesses")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)
        } else {
            Text("Guess the 6-letter word")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)
        }
    }
}

#Preview {
    BackwordCard(word: BackwordWord(date: "", word: "Seannnn", category: "", definition: ""), progress: nil)
}
