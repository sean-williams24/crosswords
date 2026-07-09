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
    @State private var showContent = false
    @State private var hasShownAd = false
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

            VStack(spacing: 32) {
                Spacer()

                // Celebration header
                VStack(spacing: 8) {
                    Text(displayState.title)
                        .font(AppFont.header(40))
                        .foregroundColor(titleColor)

                    Text("PUZZLE #\(viewModel.puzzle.puzzleNumber)")
                        .font(AppFont.clueLabel(14))
                        .foregroundColor(.appTextSecondary)
                        .tracking(3)
                }
                .scaleEffect(showContent ? 1.0 : 0.6)
                .opacity(showContent ? 1.0 : 0.0)

                Group {
                    if displayState.showsStats {
                        statsCard
                    } else if let message = displayState.message {
                        completionMessage(message)
                    }
                }
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 20)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
//                    ShareLink(item: shareText) {
//                        Label("Share Result", systemImage: "square.and.arrow.up")
//                            .font(AppFont.body())
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 14)
//                            .background(Color.appAccent)
//                            .cornerRadius(AppLayout.cardCornerRadius)
//                    }

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
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.bottom, 32)
                .opacity(showContent ? 1.0 : 0.0)
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

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showContent = true
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
        .interactiveDismissDisabled(false)
    }

    // MARK: - Components

    private var titleColor: Color {
        switch displayState.titleStyle {
        case .solved, .gaveUp:
            return .appTextHeading
        case .finished:
            return .appCorrect
        }
    }

    private var statsCard: some View {
        VStack {
            HStack(spacing: 24) {
                statItem(
                    value: "\(statsService.stats.currentStreak)",
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
        if viewModel.hasGivenUp {
            return savedReleaseDateScore ?? viewModel.progress.gaveUpScore ?? 0
        }
        return max(0, 5 - viewModel.progress.hintsUsed / 3)
    }

    private var savedReleaseDateScore: Int? {
        ratingService.rating.dailyScores
            .first { $0.date == viewModel.puzzle.date }
            .flatMap { day in
                viewModel.puzzle.size > 12 ? day.weeklyCrossword : day.dailyCrossword
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
