import SwiftUI

struct BackwordStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject var ratingService: OverallRatingService
    @EnvironmentObject var storeService: StoreService
    let stats: BackwordStats
    /// When non-nil, the bar for this guess count is highlighted (used on completion)
    var highlightGuessCount: Int? = nil
    /// Injected so previews can compile; unused at runtime.
    @Binding var shouldPop: Bool
    var isCompleted = false
    var completionProgress: BackwordProgress?
    var completionWord: String?

    @State private var animatesBars = false

    private var displayState: BackwordCompletionDisplayState {
        BackwordCompletionDisplayState.make(
            progress: completionProgress,
            isCompletion: isCompleted
        )
    }

    var body: some View {
        Group {
            if isCompleted {
                completionBody
            } else {
                statsBody
            }
        }
        .onAppear {
            ratingService.refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    animatesBars = true
                }
            }
        }
    }

    private var ratingBarView: some View {
        RatingBarView(
            rating: ratingService.rating,
            isPro: storeService.isProUser,
            category: .backword
        )
        .padding(.horizontal, AppLayout.screenPadding)
    }

    private var statsBody: some View {
        NavigationStack {
            ZStack {
                AppBackgroundGradient()
                VStack(spacing: 0) {
                    ratingBarView
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            StatsView(stats: stats)
                                .padding(.horizontal, AppLayout.screenPadding)
                            distributionSection
                                .padding(.horizontal, AppLayout.screenPadding)
                            historySection
                        }
                    }
                }
            }
            .navigationTitle("Backword Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        shouldPop = isCompleted
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
        }
    }

    private var completionBody: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if let title = displayState.title {
                            Text(title)
                                .font(AppFont.header(40))
                                .foregroundColor(titleColor)
                        }

                        if let completionWord {
                            if let completionGuessSummary {
                                Text(completionGuessSummary)
                                    .font(AppFont.body(16))
                                    .foregroundColor(.appTextSecondary)
                            }

                            BackwordCompletionWordView(
                                word: completionWord,
                                isFailed: isFailedCompletion
                            )
                        }

                        nextBackwordCountdown

                        Group {
                            ratingBarView

                            completionMessage
                            if displayState.showsStats {
                                completedStatsContent
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
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
                        .padding(.top, 14)
                }
                .padding(.horizontal, AppLayout.screenPadding)
            }
        }
    }

    private var completionGuessSummary: String? {
        guard let completionProgress, completionProgress.isComplete else { return nil }
        return BackwordCompletionText.summary(
            guessCount: completionProgress.guesses.count,
            isFailed: completionProgress.isFailed
        )
    }

    private var isFailedCompletion: Bool {
        if case .failed = displayState.titleStyle { return true }
        return false
    }

    private var nextBackwordCountdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                Text("NEXT BACKWORD IN")
                    .font(AppFont.clueLabel(12))
                    .foregroundColor(.appAccent)
                    .tracking(2)

                Text(BackwordCountdownText.value(at: context.date))
                    .font(AppFont.header(24))
                    .foregroundColor(.appTextPrimary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var titleColor: Color {
        switch displayState.titleStyle {
        case .solved:
            return .appTextHeading
        case .finished:
            return .appCorrect
        case .failed:
            return .appGaveUp
        }
    }

    @ViewBuilder
    private var completionMessage: some View {
        if let message = displayState.message {
            Text(message)
                .font(AppFont.body())
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 24)
                .background(Color.appSurface)
                .cornerRadius(AppLayout.cardCornerRadius)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal, AppLayout.screenPadding)
        }
    }

    private var completedStatsContent: some View {
        VStack(spacing: 28) {
            StatsView(stats: stats)
                .padding(.horizontal, AppLayout.screenPadding)
            distributionSection
                .padding(.horizontal, AppLayout.screenPadding)

            historySection
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    // MARK: - Distribution

    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GUESS DISTRIBUTION")
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)
                .tracking(2)
                .lineLimit(2)
                .minimumScaleFactor(0.5)

            if stats.gamesWon == 0 || stats.guessCounts.isEmpty {
                Text("No wins yet — keep playing!")
                    .font(AppFont.body(14))
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { guessNum in
                        distributionRow(guessNum: guessNum)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .strokeBorder(.clear)
        )
    }

    @ScaledMetric private var numberIconFrame: CGFloat = 16

    private func distributionRow(guessNum: Int) -> some View {
        let count = stats.count(forGuess: guessNum)
        let maxCount = max(stats.maxGuessCount, 1)
        let fraction = CGFloat(count) / CGFloat(maxCount)
        let isHighlighted = highlightGuessCount == guessNum
        let barColor: Color = isHighlighted ? .appCorrect : .appAccent

        return HStack(spacing: 10) {
            Text("\(guessNum)")
                .font(AppFont.clueLabel(14))
                .foregroundColor(.appTextSecondary)
                .frame(width: numberIconFrame, alignment: .center)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.appGridLine.opacity(0.4), lineWidth: 1)
                        )

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: isHighlighted
                                    ? [Color.appCorrect.opacity(0.8), Color.appCorrect]
                                    : [barColor.opacity(0.7), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animatesBars ? max(geo.size.width * fraction, count > 0 ? 36 : 0) : 0)
                }
            }
            .frame(height: 32)

            Text("\(count)")
                .font(AppFont.clueLabel(13))
                .foregroundColor(isHighlighted ? .appCorrect : .appTextSecondary)
                .frame(width: numberIconFrame, alignment: .center)
                .scaleEffect(isHighlighted ? 1.1 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.4), value: animatesBars)
        }
        .frame(height: 32)
    }

    // MARK: - Recent History

    private var historySection: some View {
        let rows = history.rows

        return VStack(alignment: .leading, spacing: 12) {
            Text("LAST 14 DAYS")
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)
                .tracking(2)
                .padding(.leading)

            VStack(spacing: 0) {
                HStack(spacing: historyColumnSpacing) {
                    Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Score")
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: historyScoreColumnWidth, alignment: .center)
                    Text("Guesses")
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: historyGuessesColumnWidth, alignment: .center)
                }
                .font(AppFont.clueLabel(10))
                .foregroundColor(.appTextSecondary)
                .tracking(1)
                .padding(.leading, 14)
                .padding(.trailing, dynamicTypeSize > .xxxLarge ? 14 : 0)
                .padding(.vertical, 8)

                Divider().background(Color.appGridLine)

                ForEach(Array(rows.enumerated()), id: \.element.dateStr) { index, row in
                    historyRow(row)

                    if index < rows.count - 1 {
                        Divider().background(Color.appGridLine.opacity(0.5))
                    }
                }
            }
            .background(Color.appSurface)
        }
    }

    private func historyRow(_ row: BackwordStatsHistoryRow) -> some View {
        HStack(spacing: historyColumnSpacing) {
            VStack(alignment: .leading, spacing: 1) {
                Text(formatDate(row.date))
                    .font(AppFont.body(13))
                    .foregroundColor(row.isToday ? .appAccent : .appTextPrimary)

                if row.isToday {
                    historyStatusLabel("TODAY", color: .appAccent)
                }

                switch row.outcome {
                case .solved:
                    historyStatusLabel("SOLVED", color: .solvedGold)
                case .failed:
                    historyStatusLabel("FAILED", color: .appGaveUp)
                case .unplayed, .inProgress:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ScoreChipView(score: row.score)
                .frame(width: historyScoreColumnWidth, alignment: .center)

            Group {
                if let guessCount = row.guessCount, guessCount > 0 {
                    Text("\(guessCount)")
                        .font(AppFont.body(13))
                        .foregroundColor(guessCountColor(for: row.outcome))
                        .monospacedDigit()
                } else {
                    Text("–")
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appTextSecondary.opacity(0.3))
                }
            }
            .frame(width: historyGuessesColumnWidth, alignment: .center)
        }
        .padding(.leading, 14)
        .padding(.trailing, dynamicTypeSize > .xxxLarge ? 14 : 0)
        .padding(.vertical, 10)
    }

    private func historyStatusLabel(_ title: String, color: Color) -> some View {
        Text(title)
            .font(AppFont.clueLabel(9))
            .foregroundColor(color)
            .tracking(1)
    }

    private func guessCountColor(for outcome: BackwordStatsHistoryRow.Outcome) -> Color {
        switch outcome {
        case .solved:
            return .solvedGold
        case .failed:
            return .appGaveUp
        case .unplayed, .inProgress:
            return .appTextPrimary
        }
    }

    private var historyColumnSpacing: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 8 : 4
    }

    private var historyScoreColumnWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 60 : 50
    }

    private var historyGuessesColumnWidth: CGFloat {
        72
    }

    private var history: BackwordStatsHistory {
        BackwordStatsHistory.make(
            rating: ratingService.rating,
            progressRecords: BackwordProgress.loadAll()
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Has data") {
    var s = BackwordStats()
    s.record(guessCount: 1, date: "2026-04-18")
    s.record(guessCount: 2, date: "2026-04-19")
    s.record(guessCount: 2, date: "2026-04-20")
    s.record(guessCount: 3, date: "2026-04-21")
    s.record(guessCount: nil, date: "2026-04-22")
    return BackwordStatsView(
        stats: s,
        highlightGuessCount: 2,
        shouldPop: .constant(false)
    )
        .preferredColorScheme(.dark)
        .environmentObject(OverallRatingService())
        .environmentObject(StoreService())
}

#Preview("Empty") {
    BackwordStatsView(stats: BackwordStats(), shouldPop: .constant(false))
        .preferredColorScheme(.dark)
        .environmentObject(OverallRatingService())
        .environmentObject(StoreService())
}

#Preview("Finished") {
    var progress = BackwordProgress(date: "2026-04-18")
    progress.guesses = ["CASTLE"]
    progress.wonFlag = true
    progress.completedAt = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 19))

    return BackwordStatsView(
        stats: BackwordStats(),
        highlightGuessCount: 1,
        shouldPop: .constant(false),
        isCompleted: true,
        completionProgress: progress,
        completionWord: "CASTLE"
    )
    .preferredColorScheme(.dark)
    .environmentObject(OverallRatingService())
    .environmentObject(StoreService())
}
