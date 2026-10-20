import SwiftUI

struct AnagramStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ratingService: OverallRatingService
    @EnvironmentObject private var storeService: StoreService
    @State private var progressRecords: [AnagramProgress] = []

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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                StatsHomeBar(foregroundColor: .anagramOrange, onBackToGame: { dismiss() })
            }
            .navigationTitle("Anagram Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func completionBody(_ completion: AnagramCompletion) -> some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                completionContent(completion)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                StatsHomeBar(foregroundColor: .anagramOrange, onBackToGame: { dismiss() }) {
                    dismiss()
                    shouldPop = true
                }
            }
        }
        .interactiveDismissDisabled(false)
    }

    // Keep the full layout in place while the answer animates, as Backword does.
    private func completionContent(_ completion: AnagramCompletion) -> some View {
        let displayState = AnagramCompletionDisplayState.make(completion: completion)

        return VStack(spacing: 20) {
            completionHeader(completion, displayState: displayState)
            AnagramCompletionWordView(
                word: completion.answer,
                celebrates: displayState.style == .solved
            )
            .padding(.horizontal, AppLayout.screenPadding)
            .frame(maxWidth: 560)
            nextAnagramCountdown
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
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.bottom, 28)
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
