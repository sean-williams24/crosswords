import SwiftUI

struct AnagramStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var ratingService: OverallRatingService
    @EnvironmentObject private var storeService: StoreService
    @State private var progressRecords: [AnagramProgress] = []
    @State private var showHeader = false
    @State private var showAnswer = false
    @State private var showCountdown = false
    @State private var showDetails = false

    private let previewHistory: AnagramStatsHistory?
    private let completion: AnagramCompletion?
    @Binding private var shouldPop: Bool

    init(
        previewHistory: AnagramStatsHistory? = nil,
        completion: AnagramCompletion? = nil,
        shouldPop: Binding<Bool> = .constant(false)
    ) {
        self.previewHistory = previewHistory
        self.completion = completion
        _shouldPop = shouldPop
    }

    private var history: AnagramStatsHistory {
        previewHistory ?? AnagramStatsHistory.make(
            rating: ratingService.rating,
            progressRecords: progressRecords
        )
    }

    var body: some View {
        Group {
            if let completion {
                completionBody(completion)
            } else {
                statsBody
            }
        }
        .onAppear {
            ratingService.refresh()
            guard previewHistory == nil else { return }
            progressRecords = AnagramProgress.loadAll()
        }
    }

    private var statsBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ratingBar
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    statsContent
                        .padding(.top, 20)
                        .padding(.bottom, AppLayout.anagramBottomDockInset)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Anagram Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.anagramOrange)
                    }
                    .accessibilityLabel("Close Anagram stats")
                }
            }
        }
    }

    private func completionBody(_ completion: AnagramCompletion) -> some View {
        let displayState = AnagramCompletionDisplayState.make(completion: completion)

        return ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        completionHeader(completion, displayState: displayState)

                        if showAnswer {
                            AnagramCompletionWordView(
                                word: completion.answer,
                                celebrates: displayState.style == .solved
                            )
                            .padding(.horizontal, AppLayout.screenPadding)
                            .frame(maxWidth: 560)
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                        }

                        if showCountdown {
                            nextAnagramCountdown
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        if showDetails {
                            VStack(spacing: 20) {
                                ratingBar

                                PuzzleResultShareButton(
                                    result: shareResult(for: completion),
                                    foregroundColor: .anagramOrange,
                                    backgroundColor: .anagramSurface
                                )
                                .padding(.horizontal, AppLayout.screenPadding)

                                completionStats(completion)

                                statsContent
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
                        .foregroundStyle(Color.anagramOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.bottom, 20)
                .opacity(showDetails ? 1 : 0)
            }
        }
        .task(id: completion.progress.completedAt) {
            await runCompletionPresentation(completion, displayState: displayState)
        }
        .interactiveDismissDisabled(false)
    }

    private func completionHeader(
        _ completion: AnagramCompletion,
        displayState: AnagramCompletionDisplayState
    ) -> some View {
        VStack(spacing: 8) {
            Text(displayState.title)
                .font(AppFont.header(40))
                .foregroundStyle(Color.anagramOrange)

            Text(completion.isReview ? "REVIEW PUZZLE" : "PUZZLE #\(completion.puzzle.puzzleNumber)")
                .font(AppFont.clueLabel(14))
                .foregroundStyle(Color.anagramOrange)
                .tracking(3)

            if let introduction = displayState.answerIntroduction {
                Text(introduction)
                    .font(AppFont.body())
                    .foregroundStyle(Color.anagramInk)
            }
        }
        .scaleEffect(showHeader ? 1 : 0.62)
        .opacity(showHeader ? 1 : 0)
    }

    private var nextAnagramCountdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                Text("NEXT ANAGRAM IN")
                    .font(AppFont.clueLabel(12))
                    .foregroundStyle(Color.anagramOrange)
                    .tracking(2)

                Text(AnagramCountdownText.value(at: context.date))
                    .font(AppFont.header(24))
                    .foregroundStyle(Color.anagramInk)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var ratingBar: some View {
        RatingBarView(
            rating: ratingService.rating,
            isPro: storeService.isProUser,
            category: .anagram,
            accentColor: .anagramOrange,
            trackColor: .anagramSurface
        )
        .padding(.horizontal, AppLayout.screenPadding)
    }

    private var statsContent: some View {
        VStack(spacing: 28) {
            StatsView(anagram: history)
                .padding(.horizontal, AppLayout.screenPadding)
            AnagramStatsHistoryView(rows: history.rows)
        }
    }

    private func completionStats(_ completion: AnagramCompletion) -> some View {
        HStack(spacing: 0) {
            completionStat(
                value: (completion.progress.elapsedSecondsAtCompletion ?? 0).formattedTimeHHMMSS,
                label: "TIME"
            )
            completionDivider
            completionStat(
                value: "+\(completion.progress.penaltySeconds.formattedTimeHHMMSS)",
                label: "PENALTY"
            )
            completionDivider
            completionStat(value: "\(completion.score)/5", label: "POINTS")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.anagramSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .padding(.horizontal, AppLayout.screenPadding)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func completionStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.header(22))
                .foregroundStyle(Color.anagramInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppFont.clueLabel(10))
                .foregroundStyle(Color.anagramOrange)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var completionDivider: some View {
        Rectangle()
            .fill(Color.anagramOrange.opacity(0.5))
            .frame(width: 1, height: 40)
    }

    private func shareResult(for completion: AnagramCompletion) -> PuzzleShareResult {
        PuzzleShareResult.anagram(
            completion: completion,
            history: history,
            rating: ratingService.rating,
            isPro: storeService.isProUser
        )
    }

    @MainActor
    private func runCompletionPresentation(
        _ completion: AnagramCompletion,
        displayState: AnagramCompletionDisplayState
    ) async {
        if reduceMotion {
            showHeader = true
            showAnswer = true
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
            showAnswer = true
        }
        let duration = AnagramCompletionAnimation.presentationDuration(
            letterCount: completion.answer.count,
            celebrates: displayState.style == .solved
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
}

#Preview("Stats") {
    AnagramStatsView(previewHistory: AnagramStatsHistory.make(
        rating: OverallRating(), progressRecords: []
    ))
    .environmentObject(OverallRatingService(rating: OverallRating()))
    .environmentObject(StoreService())
}

#if DEBUG
#Preview("Finished") {
    let puzzle = AnagramPuzzle.review
    let now = Date()
    var progress = AnagramProgress(puzzle: puzzle, now: now.addingTimeInterval(-75))
    for tile in [3, 0, 5, 1, 6, 2, 4, 7] {
        progress.place(tile, in: puzzle, now: now)
    }

    return AnagramStatsView(
        previewHistory: AnagramStatsHistory.make(rating: OverallRating(), progressRecords: []),
        completion: AnagramCompletion(puzzle: puzzle, progress: progress)
    )
    .environmentObject(OverallRatingService(rating: OverallRating()))
    .environmentObject(StoreService())
}
#endif
