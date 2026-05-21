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

        if let status {
            StatusLabelView(status: status)
                .padding(.bottom, 16)
        }
    }

    var status: PuzzleStatus? {
        guard let progress else { return .notStarted }
        if progress.guesses.isEmpty { return nil }
        return .inProgress
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
                let letters = Array(word.word)
                if progress?.isWon == true {
                    ForEach(0..<6, id: \.self) { i in
                        BackwordLetterCell(
                            letter: letters[i],
                            isCorrect: true,
                            size: 40                        )
                    }
                } else {
                    let revealed = BackwordViewModel.revealedIndices(for: progress, word: word.word)
                    ForEach(0..<6, id: \.self) { i in
                        BackwordLetterCell(
                            letter: revealed.contains(i) ? letters[i] : nil,
                            size: 40
                        )
                    }
                }
            }
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private func completionContent(progress: BackwordProgress) -> some View {
        VStack(spacing: 8) {
            if progress.isFailed {
                guessCounter
            } else {
                todaysWordView
            }

            StatusLabelView(status: .status(for: progress))
                .padding(.bottom, 16)
        }
    }
}

private var guessCounter: some View {
    HStack(spacing: 6) {
        ForEach(0..<5, id: \.self) { i in
            RoundedRectangle(cornerRadius: 3)
                .fill(.red)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            Color.appGridLine,
                            lineWidth: 1
                        )
                )
                .frame(width: 36, height: 10)
        }
    }
}

#Preview("Won") {
    var progress = BackwordProgress(date: "")
    progress.guesses = ["BRIDGX", "FXASXE", "CASTLE"]
    progress.wonFlag = true
    progress.completedAt = Date()
    return BackwordCard(
        service: BackwordService(),
        progress: progress
    )
}

#Preview("Failed") {
    var progress = BackwordProgress(date: "")
    progress.guesses = ["BRIDGX", "FXASXE", "CASTLE"]
    progress.wonFlag = false
    progress.completedAt = Date()
    return BackwordCard(
        service: BackwordService(),
        progress: progress
    )
}

#Preview {
    BackwordCard(
        service: BackwordService(),
        progress: nil
    )
}
