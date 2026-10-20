import SwiftUI

struct MidwordStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var ratingService: OverallRatingService
    @EnvironmentObject private var storeService: StoreService
    @State private var progressRecords: [MidwordProgress] = []
    @State private var showHeader = false
    @State private var showAnswer = false
    @State private var showCountdown = false
    @State private var showDetails = false

    let puzzle: MidwordPuzzle
    let progress: MidwordProgress
    let showsCompletion: Bool
    private let previewHistory: MidwordStatsHistory?
    @Binding private var shouldPop: Bool

    init(
        puzzle: MidwordPuzzle,
        progress: MidwordProgress,
        showsCompletion: Bool,
        previewHistory: MidwordStatsHistory? = nil,
        shouldPop: Binding<Bool> = .constant(false)
    ) {
        self.puzzle = puzzle
        self.progress = progress
        self.showsCompletion = showsCompletion
        self.previewHistory = previewHistory
        _shouldPop = shouldPop
    }

    private var history: MidwordStatsHistory {
        previewHistory ?? MidwordStatsHistory.make(
            rating: ratingService.rating,
            progressRecords: progressRecords
        )
    }

    var body: some View {
        GameDynamicTypeContainer {
            if showsCompletion { completionBody } else { statsBody }
        }
        .onAppear {
            ratingService.refresh()
            guard previewHistory == nil else { return }
            progressRecords = MidwordProgress.loadAll()
        }
    }

    private var statsBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ratingBar.padding(.top, 20).padding(.bottom, 10)
                ScrollView(showsIndicators: false) {
                    statsContent
                        .padding(.top, 20)
                        .padding(.bottom, AppLayout.anagramBottomDockInset)
                }
            }
            .background(Color.midwordBackground)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                StatsHomeBar(foregroundColor: .midwordAccent, backgroundColor: .midwordBackground, onBackToGame: { dismiss() })
            }
            .navigationTitle("Midword Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.midwordBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var completionBody: some View {
        ZStack {
            Color.midwordBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    completionHeader
                    if showAnswer {
                        MidwordCompletionWordView(word: puzzle.answer, failed: progress.isFailed)
                            .padding(.horizontal, AppLayout.screenPadding)
                            .frame(maxWidth: 560)
                            .transition(.scale(scale: 0.88).combined(with: .opacity))
                        Text("\(puzzle.firstCompound)  ·  \(puzzle.secondCompound)")
                            .font(AppFont.body())
                            .foregroundStyle(Color.midwordText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppLayout.screenPadding)
                            .transition(.opacity)
                    }
                    if showCountdown {
                        nextMidwordCountdown
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if showDetails {
                        VStack(spacing: 20) {
                            ratingBar
                            PuzzleResultShareButton(
                                result: shareResult,
                                foregroundColor: .midwordAccent,
                                backgroundColor: .midwordText.opacity(0.08)
                            )
                            .padding(.horizontal, AppLayout.screenPadding)
                            completionStats
                            statsContent
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                .padding(.bottom, 28)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                StatsHomeBar(foregroundColor: .midwordAccent, backgroundColor: .midwordBackground, onBackToGame: { dismiss() }) {
                    dismiss()
                    shouldPop = true
                }
                .opacity(showDetails ? 1 : 0)
                .allowsHitTesting(showDetails)
                .accessibilityHidden(!showDetails)
            }
        }
        .task(id: progress.completedAt) { await runCompletionPresentation() }
    }

    private var completionHeader: some View {
        VStack(spacing: 8) {
            Text(progress.isWon ? "Solved!" : "Finished")
                .font(AppFont.header(40))
                .foregroundStyle(progress.isWon ? Color.midwordAccent : Color.appGaveUp)
            Text("PUZZLE #\(puzzle.puzzleNumber)")
                .font(AppFont.clueLabel(14))
                .foregroundStyle(Color.midwordAccent)
                .tracking(3)
            Text(progress.isWon ? "In \(progress.guesses.count) guesses" : "The answer was...")
                .font(AppFont.body())
                .foregroundStyle(Color.midwordText)
        }
        .scaleEffect(showHeader ? 1 : 0.62)
        .opacity(showHeader ? 1 : 0)
    }

    private var nextMidwordCountdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                Text("NEXT MIDWORD IN")
                    .font(AppFont.clueLabel(12))
                    .foregroundStyle(Color.midwordAccent)
                    .tracking(2)
                Text(MidwordCountdownText.value(
                    secondsRemaining: ContentReleaseCalendar(now: context.date).secondsUntilDailyRefresh()
                ))
                .font(AppFont.header(24))
                .foregroundStyle(Color.midwordText)
                .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var ratingBar: some View {
        RatingBarView(
            rating: ratingService.rating,
            isPro: storeService.isProUser,
            category: .midword,
            accentColor: .midwordAccent,
            trackColor: .midwordText.opacity(0.12)
        )
        .padding(.horizontal, AppLayout.screenPadding)
    }

    private var statsContent: some View {
        VStack(spacing: 28) {
            summaryCard.padding(.horizontal, AppLayout.screenPadding)
            guessDistributionCard.padding(.horizontal, AppLayout.screenPadding)
            MidwordStatsHistoryView(rows: history.rows)
        }
    }

    private var completionStats: some View {
        HStack(spacing: 0) {
            completionStat(value: "\(progress.guesses.count)/5", label: "GUESSES")
            divider
            completionStat(value: "\(progress.releaseDateScore)/5", label: "POINTS")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.midwordText.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .padding(.horizontal, AppLayout.screenPadding)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var summaryCard: some View {
        ViewThatFits {
            HStack(spacing: 0) {
                completionStat(value: "\(history.currentStreak)", label: "CURRENT\nSTREAK")
                divider
                completionStat(value: "\(history.totalSolved)", label: "TOTAL\nSOLVED")
                divider
                completionStat(value: "\(history.bestStreak)", label: "BEST\nSTREAK")
            }
            VStack(spacing: 16) {
                completionStat(value: "\(history.currentStreak)", label: "CURRENT STREAK")
                completionStat(value: "\(history.totalSolved)", label: "TOTAL SOLVED")
                completionStat(value: "\(history.bestStreak)", label: "BEST STREAK")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.midwordText.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var guessDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GUESS DISTRIBUTION")
                .font(AppFont.clueLabel(12))
                .foregroundStyle(Color.midwordAccent)
                .tracking(2)
            ForEach(1...5, id: \.self) { guessCount in
                HStack(spacing: 10) {
                    Text("\(guessCount)")
                        .font(AppFont.clueLabel(11))
                        .foregroundStyle(Color.midwordText)
                        .frame(width: 14)
                    GeometryReader { geometry in
                        let count = history.guessDistribution[guessCount, default: 0]
                        let maximum = max(1, history.guessDistribution.values.max() ?? 0)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.midwordText.opacity(0.08))
                            Capsule().fill(Color.midwordAccent)
                                .frame(width: max(count > 0 ? 8 : 0, geometry.size.width * CGFloat(count) / CGFloat(maximum)))
                        }
                    }
                    .frame(height: 18)
                    Text("\(history.guessDistribution[guessCount, default: 0])")
                        .font(AppFont.body(12))
                        .foregroundStyle(Color.midwordText)
                        .frame(width: 22, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(Color.midwordText.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
    }

    private func completionStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.header(24))
                .foregroundStyle(Color.midwordText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(AppFont.clueLabel(10))
                .foregroundStyle(Color.midwordAccent)
                .tracking(1)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.midwordAccent.opacity(0.5)).frame(width: 1, height: 40)
    }

    private var shareResult: PuzzleShareResult {
        .midword(
            puzzle: puzzle,
            progress: progress,
            history: history,
            rating: ratingService.rating,
            isPro: storeService.isProUser
        )
    }

    @MainActor
    private func runCompletionPresentation() async {
        if reduceMotion {
            showHeader = true
            showAnswer = true
            showCountdown = true
            showDetails = true
            return
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) { showHeader = true }
        try? await Task.sleep(for: .milliseconds(220))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) { showAnswer = true }
        try? await Task.sleep(for: .milliseconds(900))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) { showCountdown = true }
        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { showDetails = true }
    }
}

enum MidwordCountdownText {
    static func value(secondsRemaining: TimeInterval?) -> String {
        guard let secondsRemaining else { return "--:--:--" }
        let totalSeconds = Int(ceil(max(0, secondsRemaining)))
        return String(
            format: "%02d:%02d:%02d",
            totalSeconds / 3_600,
            (totalSeconds % 3_600) / 60,
            totalSeconds % 60
        )
    }
}
