import SwiftUI

struct BackwordCard: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.colorScheme) private var systemColorScheme
    @EnvironmentObject private var statsService: BackwordStatsService
    @ScaledMetric private var spacing: CGFloat = 10
    @ObservedObject private var settings = AppSettings.shared
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
        HomeGameCardContent(
            minimumHeight: appLayout.cardHeight,
            identityPosition: progress?.isComplete == true ? .top : .center,
            spacing: AnagramHomeCardLayout.identitySpacing
        ) {
            BackwordLogo(frame: AppLayout.homeCardLogoHeight, forceDark: true)
        } details: {
            bottomStatsView
        } accessory: {
            if let progress, progress.isComplete {
                completedPuzzleContent(progress: progress)
            } else if service.isLoading {
                loadingView
            } else if service.todaysWord == nil {
                errorView
            }
        } header: {
            HomeGameCardHeader(spacing: AnagramHomeCardLayout.statsSpacing) {
                EmptyView()
            } streak: {
                StreakButton(
                    streak: statsService.stats.liveCurrentStreak,
                    backgroundStyle: .inProgress,
                    borderStyle: badgeBorderStyle
                )
            }
        }
        .background(
            cardBackground.environment(
                \.colorScheme,
                BackwordCardAppearance.backgroundColorScheme(for: systemColorScheme)
            )
        )
        .background(Color.appCrosswordBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .environment(\.colorScheme, BackwordAppearance.colorScheme)
    }

    @ViewBuilder
    private var issueNumberLabel: some View {
        if let issueNumber = service.todaysWord?.puzzleNumber {
            HomeCardIssueNumber(issueNumber: issueNumber)
        }
    }

    private var cardBackground: some View {
        Color.backwordBackground
    }

    private var bottomStatsView: some View {
        HomeGameCardFooter(spacing: AnagramHomeCardLayout.statsSpacing) {
            scoreView
        } status: {
            statusLabel
        } issue: {
            issueNumberLabel
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
    private var statusLabel: some View {
        if let progress, progress.isComplete {
            StatusLabelView(
                status: .status(for: progress),
                textStyle: BackwordCardStatusStyle.textStyle,
                borderStyle: badgeBorderStyle
            )
        } else if !service.isLoading, service.todaysWord != nil, let status {
            StatusLabelView(
                status: status,
                textStyle: BackwordCardStatusStyle.textStyle,
                backgroundStyle: BackwordCardStatusStyle.backgroundStyle(
                    for: status,
                    systemColorScheme: systemColorScheme
                ),
                borderStyle: badgeBorderStyle
            )
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
                            size: AppLayout.homeCardLetterCellSize,
                            correctCellStyle: BackwordCardAppearance.correctCellStyle(
                                for: systemColorScheme
                            )
                        )
                    }
                } else {
                    let revealed = BackwordViewModel.revealedIndices(
                        for: progress,
                        word: word.word,
                        mode: settings.backwordMode
                    )
                    ForEach(0..<6, id: \.self) { i in
                        BackwordLetterCell(
                            letter: revealed.contains(i) ? letters[i] : nil,
                            size: AppLayout.homeCardLetterCellSize
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

}

private extension BackwordCard {
    var badgeBorderStyle: HomeCardBadgeBorderStyle {
        BackwordCardAppearance.badgeBorderStyle(for: systemColorScheme)
    }
}

enum BackwordCardStatusStyle {
    static let textStyle: StatusLabelTextStyle = .primary

    static func backgroundStyle(
        for status: PuzzleStatus,
        systemColorScheme: ColorScheme
    ) -> StatusLabelBackgroundStyle {
        guard systemColorScheme == .light else { return .status }
        guard case .notStarted = status else { return .status }

        return .inProgress
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
