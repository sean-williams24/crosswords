import SwiftUI

struct CrosswordStatsView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var ratingService: OverallRatingService
    let isWeekly: Bool
    let isPro: Bool
    var onDismiss: (() -> Void)? = nil

    private var category: RatingGameCategory {
        isWeekly ? .weeklyCrossword : .dailyCrossword
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RatingBarView(
                    rating: ratingService.rating,
                    isPro: isPro,
                    category: category
                )
                .padding(.top, 20)
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        StatsView(
                            stats: statsService.stats,
                            isWeekly: isWeekly,
                            displayedAverageTime: averageSolveTime
                        )
                            .padding(.horizontal, AppLayout.screenPadding)
                        recentHistory
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(AppBackgroundGradient())
            .navigationTitle(isWeekly ? "Weekly Stats" : "Daily Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onDismiss?() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
        }
        .onAppear {
            ratingService.refresh()
        }
    }
    
    // MARK: - Recent History

    @ViewBuilder
    private var recentHistory: some View {
        if isWeekly {
            VStack(spacing: 28) {
                historySection(title: "LAST 14 DAYS", rows: weeklyHistory.last14Days)
                historySection(title: "PREVIOUS GAMES", rows: weeklyHistory.previousGames)
            }
        } else {
            historySection(title: "LAST 14 DAYS", rows: dailyBreakdownRows)
        }
    }

    private var averageSolveTime: String {
        CrosswordSolveTimeSummary.displayedAverageTime(
            from: isWeekly ? weeklyHistory.last14Days : dailyBreakdownRows
        )
    }

    @ViewBuilder
    private func historySection(title: String, rows: [CrosswordStatsHistoryRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)
                .tracking(2)
                .padding(.horizontal, AppLayout.screenPadding)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Score").frame(width: 50, alignment: .center)
                    Text("Time").frame(width: 72, alignment: .center)
                }
                .font(AppFont.clueLabel(10))
                .foregroundColor(.appTextSecondary)
                .tracking(1)
                .padding(.leading, 14)
                .padding(.vertical, 8)

                Divider().background(Color.appGridLine)

                ForEach(Array(rows.enumerated()), id: \.element.dateStr) { idx, row in
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(formatDate(row.date))
                                .font(AppFont.body(13))
                                .foregroundColor(row.isToday ? .appAccent : .appTextPrimary)
                            if row.isToday {
                                Text("TODAY")
                                    .font(AppFont.clueLabel(9))
                                    .foregroundColor(.appAccent)
                                    .tracking(1)
                            }
                            if row.isSolved {
                                Text("SOLVED")
                                    .font(AppFont.clueLabel(9))
                                    .foregroundColor(.solvedGold)
                                    .tracking(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ScoreChipView(score: row.score)
                            .frame(width: 50, alignment: .center)

                        Group {
                            if let time = row.solveTime {
                                Text(time.formattedTimeHHMMSS)
                                    .font(AppFont.body(13))
                                    .foregroundColor(.solvedGold)
                                    .monospacedDigit()
                                    .frame(width: 72, alignment: .center)
                            } else {
                                Text("–")
                                    .font(AppFont.clueLabel(12))
                                    .foregroundColor(.appTextSecondary.opacity(0.3))
                                    .frame(width: 72, alignment: .center)
                            }
                        }
                        .frame(width: 72)
                    }
                    .padding(.leading, 14)
                    .padding(.vertical, 10)

                    if idx < rows.count - 1 {
                        Divider().background(Color.appGridLine.opacity(0.5))
                    }
                }
            }
            .background(Color.appSurface)
        }
    }

    // MARK: - Row Data

    private var dailyBreakdownRows: [CrosswordStatsHistoryRow] {
        let scoreMap: [String: Int] = Dictionary(uniqueKeysWithValues:
            ratingService.rating.dailyScores.map { ($0.date, $0.dailyCrossword) }
        )
        let timeMap = CrosswordSolveTimeSummary.solveTimeByDailyDate(from: UserProgress.loadAll())
        let todayStr = ContentReleaseCalendar().dailyDateString
        return (0..<14).compactMap { offset -> CrosswordStatsHistoryRow? in
            guard let dateStr = ContentReleaseCalendar().dailyDateString(offsetByDays: -offset),
                  let date = OverallRating.dateFormatter.date(from: dateStr) else { return nil }
            let solveTime = timeMap[dateStr]
            let ratingScore = scoreMap[dateStr]
            let score = ratingScore ?? (solveTime != nil ? 5 : 0)
            return CrosswordStatsHistoryRow(
                dateStr: dateStr,
                date: date,
                isToday: dateStr == todayStr,
                score: score,
                solveTime: solveTime,
                isSolved: solveTime != nil
            )
        }
    }

    private var weeklyHistory: WeeklyCrosswordStatsHistory {
        WeeklyCrosswordStatsHistory.make(
            rating: ratingService.rating,
            progressRecords: UserProgress.loadAll()
        )
    }
    
    // MARK: - Formatting
    
    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: date)
    }
}

#Preview {
    CrosswordStatsView(isWeekly: false, isPro: false) { }
        .environmentObject(CrosswordStatsView.mockStatsService)
        .environmentObject(CrosswordStatsView.mockRatingService)
}

#Preview("Weekly") {
    CrosswordStatsView(isWeekly: true, isPro: true) { }
        .environmentObject(CrosswordStatsView.mockStatsService)
        .environmentObject(CrosswordStatsView.mockRatingService)
}

private extension CrosswordStatsView {
    static var mockStatsService: StatsService { mockService }
    static var mockService: StatsService {
        var mockStats = UserStats()
        mockStats.currentStreak = 3
        mockStats.longestStreak = 7
        mockStats.totalCompleted = 12
        mockStats.averageTimeSeconds = 6486.0
        mockStats.lastCompletedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        mockStats.history = [
            PuzzleResult(puzzleId: "1", date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, timeSeconds: 5320, hintsUsed: 0, isWeekly: true),
            PuzzleResult(puzzleId: "2", date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, timeSeconds: 8410, hintsUsed: 1, isWeekly: true),
            PuzzleResult(puzzleId: "3", date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, timeSeconds: 290, hintsUsed: 0),
            PuzzleResult(puzzleId: "4", date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, timeSeconds: 370, hintsUsed: 2),
            PuzzleResult(puzzleId: "5", date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, timeSeconds: 330, hintsUsed: 0),
            PuzzleResult(puzzleId: "6", date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, timeSeconds: 355, hintsUsed: 0),
            PuzzleResult(puzzleId: "7", date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!, timeSeconds: 400, hintsUsed: 1),
            PuzzleResult(puzzleId: "8", date: Calendar.current.date(byAdding: .day, value: -8, to: Date())!, timeSeconds: 315, hintsUsed: 0),
            PuzzleResult(puzzleId: "9", date: Calendar.current.date(byAdding: .day, value: -9, to: Date())!, timeSeconds: 360, hintsUsed: 0),
            PuzzleResult(puzzleId: "10", date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!, timeSeconds: 390, hintsUsed: 2)
        ]
        let mockService = StatsService()
        mockService.stats = mockStats
        return mockService
    }

    static var mockRatingService: OverallRatingService {
        var r = OverallRating()
        // Only score days that also have times in the history (days 1–10 above)
        let dailyScores = [0, 0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 0, 0, 0]
        for (i, score) in dailyScores.enumerated() {
            guard score > 0,
                  let dateString = ContentReleaseCalendar().dailyDateString(offsetByDays: -i) else { continue }
            r.upsertDailyCrossword(score: score, date: dateString)
        }
        return OverallRatingService(rating: r)
    }
}
