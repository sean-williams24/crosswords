import SwiftUI

struct BackwordCard: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var statsService: BackwordStatsService
    @ScaledMetric private var spacing: CGFloat = 10
    @ObservedObject var service: BackwordService
    let progress: BackwordProgress?
    var showBackword: () -> Void

    private var appLayout: AppLayout {
        AppLayout(sizeClass: sizeClass)
    }

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
                Button {
                    showBackword()
                } label: {
                    cardContainer
                }
            }
        }
    }

    private var cardContainer: some View {
        VStack(alignment: .center, spacing: 0) {
            VStack(alignment: .center, spacing: 0) {
                BackwordLogo(frame: 48)
                    .padding(.vertical, 10)

                if let progress, progress.isComplete {
                    completedPuzzleContent(progress: progress)
                        .padding(.bottom, 8)
                } else if service.isLoading {
                    loadingView
                } else if service.todaysWord == nil {
                    errorView
                } else {
                    playView
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            if let progress, progress.isComplete {
                completedStatsView(progress: progress)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            } else {
                bottomStatsView
                    .padding(.horizontal, HomeCardStreakLayout.streakButtonEdgeInset)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, minHeight: appLayout.cardHeight)
        .background(Color.appCrosswordBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .strokeBorder(Color.appAccent, lineWidth: 2)
        )
    }

    private var bottomStatsView: some View {
        HStack {
            scoreView
            Spacer(minLength: 2)
            StreakButton(streak: statsService.stats.liveCurrentStreak)
        }
    }

    @ViewBuilder
    private var scoreView: some View {
        if let score = progress?.completedScore {
            HStack(spacing: 4) {
                Text("\(score)")
                    .font(AppFont.header(24))
                    .foregroundColor(score == 5 ? .appCorrect : .appAccent)
                Text("/ 5")
                    .font(AppFont.header(12))
                    .foregroundColor(.appTextSecondary)
            }
        }
    }

    @ViewBuilder
    private var playView: some View {
//        todaysWordView

//        Text(guessInfoText)
//            .font(AppFont.caption())
//            .foregroundColor(.appTextPrimary)
//            .padding(.bottom, 16)

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
        }
    }

    @ViewBuilder
    private func completedPuzzleContent(progress: BackwordProgress) -> some View {
        VStack(spacing: 8) {
            if progress.isFailed {
                guessCounter
            } else {
                todaysWordView
            }
        }
    }

    @ViewBuilder
    private func completedStatsView(progress: BackwordProgress) -> some View {
        if dynamicTypeSize > .accessibility1 {
            VStack(spacing: 8) {
                StatusLabelView(status: .status(for: progress))
                    .fixedSize(horizontal: true, vertical: false)
                bottomStatsView
            }
            .padding(.horizontal, HomeCardStreakLayout.streakButtonEdgeInset)
            .frame(maxWidth: .infinity)
        } else {
            horizontalCompletedStatsView(progress: progress)
        }
    }

    private func horizontalCompletedStatsView(progress: BackwordProgress) -> some View {
        ZStack {
            HStack(alignment: .center) {
                scoreView
                Spacer(minLength: 2)
                StreakButton(streak: statsService.stats.liveCurrentStreak)
            }

            StatusLabelView(status: .status(for: progress))
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, HomeCardStreakLayout.streakButtonEdgeInset)
        .frame(maxWidth: .infinity)
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
        progress: progress,
        showBackword: {}
    )
    .environmentObject(BackwordStatsService())
}

#Preview("Failed") {
    var progress = BackwordProgress(date: "")
    progress.guesses = ["BRIDGX", "FXASXE", "CASTLE"]
    progress.wonFlag = false
    progress.completedAt = Date()
    return BackwordCard(
        service: BackwordService(),
        progress: progress,
        showBackword: {}
    )
    .environmentObject(BackwordStatsService())
}

#Preview {
    BackwordCard(
        service: BackwordService(),
        progress: nil,
        showBackword: {}
    )
    .environmentObject(BackwordStatsService())
}
