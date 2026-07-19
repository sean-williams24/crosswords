import SwiftUI

struct CompletionView: View {
    @ObservedObject var viewModel: GameViewModel
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @EnvironmentObject var ratingService: OverallRatingService
    @EnvironmentObject var appReviewPromptService: AppReviewPromptService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHeader = false
    @State private var showGrid = false
    @State private var showCountdown = false
    @State private var showDetails = false
    @Binding var shouldPop: Bool

    private var displayState: CompletionDisplayState {
        CompletionDisplayState.make(
            puzzle: viewModel.puzzle,
            progress: viewModel.progress,
            hasGivenUp: viewModel.hasGivenUp
        )
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        celebrationHeader

                        if showGrid {
                            CrosswordCompletionGridView(
                                puzzle: viewModel.puzzle,
                                style: gridStyle
                            )
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                        }

                        if showCountdown {
                            nextCrosswordCountdown
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if showDetails {
                            VStack(spacing: 20) {
                                if let message = displayState.message {
                                    completionMessage(message)
                                }

                                if displayState.showsStats {
                                    statsCard
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.bottom, 28)
                }

                Button {
                    dismiss()
                    shouldPop = true
                } label: {
                    Text("HOME")
                        .font(AppFont.body())
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.bottom, 20)
                .opacity(showDetails ? 1 : 0)
            }
        }
        .onAppear {
            if !viewModel.hasGivenUp {
                statsService.recordCompletion(
                    puzzleId: viewModel.puzzle.id,
                    timeSeconds: Int(viewModel.progress.elapsedTime),
                    hintsUsed: viewModel.progress.hintsUsed,
                    isWeekly: viewModel.puzzle.size > 12
                )
            }

            if !viewModel.hasGivenUp {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    appReviewPromptService.recordEligibleCrosswordCompletion(
                        puzzleId: viewModel.puzzle.id,
                        gaveUp: viewModel.hasGivenUp
                    )
                }
            }
        }
        .task {
            await runPresentation()
        }
        .interactiveDismissDisabled(false)
    }

    // MARK: - Components

    private var titleColor: Color {
        switch displayState.titleStyle {
        case .solved:
            return .appTextHeading
        case .finished:
            return .appCorrect
        case .gaveUp:
            return .appGaveUp
        }
    }

    private var celebrationHeader: some View {
        VStack(spacing: 8) {
            Text(displayState.title)
                .font(AppFont.header(40))
                .foregroundColor(titleColor)

            Text("PUZZLE #\(viewModel.puzzle.puzzleNumber)")
                .font(AppFont.clueLabel(14))
                .foregroundColor(.appTextSecondary)
                .tracking(3)
        }
        .scaleEffect(showHeader ? 1 : 0.62)
        .opacity(showHeader ? 1 : 0)
    }

    private var gridStyle: CrosswordCompletionGridStyle {
        CrosswordCompletionGridStyle(titleStyle: displayState.titleStyle)
    }

    private var releaseKind: CrosswordReleaseKind {
        isWeekly ? .weekly : .daily
    }

    private var isWeekly: Bool {
        viewModel.puzzle.size > 12
    }

    private var nextCrosswordCountdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                Text(releaseKind.label)
                    .font(AppFont.clueLabel(12))
                    .foregroundColor(.appAccent)
                    .tracking(2)
                    .multilineTextAlignment(.center)

                Text(CrosswordCountdownText.value(at: context.date, kind: releaseKind))
                    .font(AppFont.header(24))
                    .foregroundColor(.appTextPrimary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var statsCard: some View {
        VStack {
            HStack(spacing: 24) {
                statItem(
                    value: "\(CrosswordCompletionMetrics.streak(stats: statsService.stats, isWeekly: isWeekly))",
                    label: "STREAK"
                )
                statDivider
                statItem(
                    value: "\(viewModel.progress.hintsUsed)",
                    label: "HINTS"
                )
            }
            HStack(spacing: 24) {
                statItem(
                    value: "\(completionScore)/5",
                    label: "SCORE"
                )
                statDivider
                statItem(
                    value: viewModel.progress.formattedTime,
                    label: "TIME"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(Color.appSurface)
        .cornerRadius(AppLayout.cardCornerRadius)
        .padding(.horizontal, AppLayout.screenPadding)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func completionMessage(_ message: String) -> some View {
        Text(message)
            .font(AppFont.body())
            .foregroundColor(.appTextSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)
            .padding(.horizontal, AppLayout.screenPadding)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    @ViewBuilder
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.header(28))
                .foregroundColor(.appTextPrimary)
            Text(label)
                .font(AppFont.clueLabel(10))
                .foregroundColor(.appTextSecondary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.appGridLine)
            .frame(width: 1, height: 40)
    }

    private var completionScore: Int {
        CrosswordCompletionMetrics.score(
            titleStyle: displayState.titleStyle,
            hasGivenUp: viewModel.hasGivenUp,
            hintsUsed: viewModel.progress.hintsUsed,
            gaveUpScore: viewModel.progress.gaveUpScore,
            savedReleaseDateScore: savedReleaseDateScore
        )
    }

    private var savedReleaseDateScore: Int? {
        ratingService.rating.dailyScores
            .first { $0.date == viewModel.puzzle.date }
            .flatMap { day in
                viewModel.puzzle.size > 12 ? day.weeklyCrossword : day.dailyCrossword
            }
    }

    @MainActor
    private func runPresentation() async {
        if reduceMotion {
            showHeader = true
            showGrid = true
            showCountdown = true
            showDetails = true
            return
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {
            showHeader = true
        }
        try? await Task.sleep(nanoseconds: 220_000_000)
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
            showGrid = true
        }

        let duration = CrosswordCompletionAnimation.presentationDuration(
            cells: viewModel.puzzle.cells,
            celebrates: gridStyle.performsBounce
        )
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.3)) {
            showCountdown = true
        }
        try? await Task.sleep(nanoseconds: 180_000_000)
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            showDetails = true
        }
    }

    // MARK: - Share

    private var shareText: String {
        let streak = statsService.stats.currentStreak
        let hints = viewModel.progress.hintsUsed
        let time = viewModel.progress.formattedTime
        let number = viewModel.puzzle.puzzleNumber

        var text = "Crosswords #\(number) 🟩\n"
        text += "⏱ \(time)"
        if streak > 1 { text += " | 🔥 \(streak)-day streak" }
        if hints == 0 { text += " | 💡 No hints" }
        else { text += " | 💡 \(hints) hint\(hints == 1 ? "" : "s")" }
        return text
    }
}

#Preview {
    CompletionView(viewModel: GameViewModel(puzzle: .sample), shouldPop: .constant(false))
        .environmentObject(StatsService())
        .environmentObject(StoreService())
        .environmentObject(AdService())
        .environmentObject(OverallRatingService())
        .environmentObject(AppReviewPromptService())
}
