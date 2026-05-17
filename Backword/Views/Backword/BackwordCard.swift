import SwiftUI

struct BackwordCard: View {
    @ScaledMetric private var spacing: CGFloat = 10
    @ObservedObject var service: BackwordService
    let progress: BackwordProgress?

    var body: some View {
        Group {
            if service.isLoading {
                cardContainer
            } else if service.todaysWord == nil {
                Button(action: retryFetch) {
                    cardContainer
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink(value: "backword") {
                    cardContainer
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cardContainer: some View {
        VStack(alignment: .center, spacing: 0) {
            BackwordLogo(frame: 48)
                .padding(.vertical, 10)

            if let progress, progress.isComplete {
                completionContent(progress: progress)
            } else if service.isLoading {
                loadingView
            } else if service.todaysWord == nil {
                errorView
            } else {
                playView
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
    private var playView: some View {
        todaysWordView

        Text(guessInfoText)
            .font(AppFont.caption())
            .foregroundColor(.appTextSecondary)
            .padding(.bottom, 16)
    }

    private var errorView: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Failed to load today's puzzle.")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                Text("Tap to retry")
            }
            .font(AppFont.caption().bold())
            .foregroundColor(.appAccent)
        }
        .padding(.bottom, 16)
    }

    private func retryFetch() {
        Task {
            await service.refreshIfNeeded(force: true)
        }
    }

    private var guessInfoText: String {
        guard let progress, !progress.guesses.isEmpty else {
            return "Guess the 6-letter word"
        }
        return "\(progress.guesses.count) / 5 guesses"
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(height: 34)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var todaysWordView: some View {
        if let word = service.todaysWord {
            HStack(spacing: 6) {
                let revealedCount = progress?.revealedCount ?? 1
                let revealed = BackwordViewModel.revealedIndices(forRevealedCount: revealedCount)
                let letters = Array(word.word)
                ForEach(0..<6, id: \.self) { i in
                    BackwordLetterCell(
                        letter: revealed.contains(i) ? letters[i] : nil,
                        size: 40
                    )
                }
            }
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private func completionContent(progress: BackwordProgress) -> some View {
        HStack(spacing: 8) {
            Image(systemName: progress.wonFlag ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(progress.wonFlag ? .appCorrect : .red.opacity(0.7))
                .font(.system(size: 16))

            Text(progress.wonFlag
                 ? "Completed in \(progress.guesses.count) guess\(progress.guesses.count == 1 ? "" : "es")"
                 : "Better luck tomorrow")
                .font(AppFont.body(14))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(progress.wonFlag ? 0 : 1)
                .padding()
        }
    }
}

#Preview {
    VStack {
        BackwordCard(
            service: BackwordService(),
            //            word: BackwordWord(
            //                date: "",
            //                word: "Seannnn",
            //                category: "",
            //                definition: ""
            //            ),
            progress: nil
        )

        BackwordCard(
            service: BackwordService(),
            progress: nil
        )
    }
}
