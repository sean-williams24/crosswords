import SwiftUI

struct CrosswordStatsView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var ratingService: OverallRatingService
    let isWeekly: Bool
    var onDismiss: (() -> Void)? = nil
    
    @State private var animates = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.appAccent.opacity(0.10), Color.appBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isWeekly && statsService.stats.totalCompleted(isWeekly: true) == 0 {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            summaryRow
                            recentHistory
                        }
                        .padding(.horizontal, AppLayout.screenPadding)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    animates = true
                }
            }
        }
    }
    
    // MARK: - Summary Row
    
    private var summaryRow: some View {
        VStack {
            HStack(spacing: 0) {
                statCell(
                    value: "\(statsService.stats.currentStreak(isWeekly: isWeekly))",
                    label: "Current\n Streak",
                    icon: statsService.stats.currentStreak(isWeekly: isWeekly) > 0 ? "flame.fill" : nil,
                    iconColor: .orange
                )
                divider
                statCell(value: "\(statsService.stats.totalCompleted(isWeekly: isWeekly))", label: "Solved\n")
                divider
                statCell(value: "\(statsService.stats.longestStreak(isWeekly: isWeekly))", label: "Best\n Streak")
                divider
            }
            statCell(value: statsService.stats.formattedAverageTime(isWeekly: isWeekly), label: "Avg Time")
                .padding(.top)
            
        }
        .padding(.vertical, 20)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.appGridLine.opacity(0.5))
            .frame(width: 1, height: 40)
    }
    
    private func statCell(
        value: String,
        label: String,
        icon: String? = nil,
        iconColor: Color = .appAccent
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(iconColor)
                }
                Text(value)
                    .font(AppFont.header(22))
                    .foregroundColor(.appTextPrimary)
            }
            Text(label)
                .font(AppFont.clueLabel(10))
                .foregroundColor(.appTextSecondary)
                .tracking(1)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Recent History

    @ViewBuilder
    private var recentHistory: some View {
        if isWeekly {
            weeklyHistorySection
        } else {
            dailyBreakdownSection
        }
    }

    private var dailyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST 14 DAYS")
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)
                .tracking(2)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Score").frame(width: 50, alignment: .center)
                    Text("Time").frame(width: 72, alignment: .trailing)
                }
                .font(AppFont.clueLabel(10))
                .foregroundColor(.appTextSecondary)
                .tracking(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Divider().background(Color.appGridLine)

                ForEach(Array(dailyBreakdownRows.enumerated()), id: \.element.dateStr) { idx, row in
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

                        scoreChip(row.score, hasEntry: row.hasEntry)
                            .frame(width: 50, alignment: .center)

                        if let time = row.solveTime {
                            Text(time.formattedTimeHHMMSS)
                                .font(AppFont.body(13))
                                .foregroundColor(.solvedGold)
                                .monospacedDigit()
                                .frame(width: 72, alignment: .trailing)
                        } else {
                            Text("–")
                                .font(AppFont.clueLabel(12))
                                .foregroundColor(.appTextSecondary.opacity(0.3))
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if idx < dailyBreakdownRows.count - 1 {
                        Divider().background(Color.appGridLine.opacity(0.5))
                    }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                    .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
            )
        }
    }

//    private func titleView(row: DailyRow) -> some View {
//        Text(formatDate(row.date))
//            .font(AppFont.body(13))
//            .foregroundColor(row.isToday ? .appAccent : .appTextPrimary)
//    }

//    @ViewBuilder
//    private func titleSubView(row: DailyRow) -> some View {
//        if row.isToday {
//            Text("TODAY")
//                .font(AppFont.clueLabel(9))
//                .foregroundColor(.appAccent)
//                .tracking(1)
//        }
//        if row.isSolved {
//            Text("SOLVED")
//                .font(AppFont.clueLabel(9))
//                .foregroundColor(.solvedGold)
//                .tracking(1)
//        }
//    }
//
//    private func horizontalTitleStack(for row: DailyRow) -> some View {
//        HStack {
//            titleView(row: row)
//            titleSubView(row: row)
//        }
//    }
//
//    private func verticalTitleStack(for row: DailyRow) -> some View {
//        VStack {
//            titleView(row: row)
//            titleSubView(row: row)
//        }
//    }

    private var weeklyHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT GAMES")
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)
                .tracking(2)

            VStack(spacing: 0) {
                let history = statsService.stats.filteredHistory(isWeekly: true).suffix(10).reversed()
                ForEach(Array(history.enumerated()), id: \.element.id) { index, result in
                    HStack(spacing: 12) {
                        Text(formatDate(result.date))
                            .font(AppFont.body(14))
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                        Text(result.timeSeconds.formattedTimeHHMMSS)
                            .font(AppFont.body(14))
                            .foregroundColor(.appTextSecondary)
                            .monospacedDigit()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.appCorrect)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < min(9, statsService.stats.filteredHistory(isWeekly: true).count - 1) {
                        Divider().background(Color.appGridLine)
                    }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                    .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Daily Breakdown Data

    private struct DailyRow {
        let dateStr: String
        let date: Date
        let isToday: Bool
        let score: Int
        let hasEntry: Bool
        let solveTime: Int?
        let isSolved: Bool
    }

    private var dailyBreakdownRows: [DailyRow] {
        let utcFmt = DateFormatter()
        utcFmt.dateFormat = "yyyy-MM-dd"
        utcFmt.timeZone = TimeZone(identifier: "UTC")

        let scoreMap: [String: Int] = Dictionary(uniqueKeysWithValues:
            ratingService.rating.dailyScores.map { ($0.date, $0.dailyCrossword) }
        )
        // Build time map from UserProgress files, keyed by the puzzle's scheduled UTC date.
        // Only include puzzles completed on the same UTC date as the puzzle date (i.e. solved on time),
        // matching the "Solved" status shown in the archive view.
        var timeMap = [String: Int]()
        for progress in UserProgress.loadAll() {
            guard progress.isWeekly != true,
                  let puzzleDate = progress.puzzleDate,
                  let completedAt = progress.completedAt,
                  utcFmt.string(from: completedAt) == puzzleDate else { continue }
            timeMap[puzzleDate] = Int(progress.elapsedTime)
        }
        let todayStr = utcFmt.string(from: Date())
        return (0..<14).compactMap { offset -> DailyRow? in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let dateStr = utcFmt.string(from: date)
            let solveTime = timeMap[dateStr]
            let ratingScore = scoreMap[dateStr]
            let score = ratingScore ?? (solveTime != nil ? 5 : 0)
            let hasEntry = solveTime != nil || ratingScore != nil
            return DailyRow(
                dateStr: dateStr,
                date: date,
                isToday: dateStr == todayStr,
                score: score,
                hasEntry: hasEntry,
                solveTime: solveTime,
                isSolved: solveTime != nil
            )
        }
    }

    private func scoreChip(_ score: Int, hasEntry: Bool) -> some View {
        let color: Color = !hasEntry ? .appTextSecondary.opacity(0.1)
            : score == 5 ? .appCorrect
            : score > 0 ? .appAccent
            : .appTextSecondary.opacity(0.25)
        let textColor: Color = hasEntry && score > 0 ? .white : .appTextSecondary.opacity(0.4)
        return Text(hasEntry ? "\(score)" : "–")
            .font(AppFont.clueLabel(12))
            .foregroundColor(textColor)
            .frame(width: 24, height: 24)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.appTextSecondary.opacity(0.4))
            Text("No puzzles solved yet")
                .font(AppFont.body())
                .foregroundColor(.appTextSecondary)
            Text("Complete a crossword to see your stats here.")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Formatting
    
    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: date)
    }
}

#Preview {
    CrosswordStatsView(isWeekly: false) { }
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
            PuzzleResult(puzzleId: "1", date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, timeSeconds: 5320, hintsUsed: 0),
            PuzzleResult(puzzleId: "2", date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, timeSeconds: 8410, hintsUsed: 1),
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
        let utcFmt = DateFormatter()
        utcFmt.dateFormat = "yyyy-MM-dd"
        utcFmt.timeZone = TimeZone(identifier: "UTC")
        // Only score days that also have times in the history (days 1–10 above)
        let dailyScores = [0, 0, 5, 5, 5, 5, 5, 5, 5, 5, 5, 0, 0, 0]
        for (i, score) in dailyScores.enumerated() {
            guard score > 0,
                  let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) else { continue }
            r.upsertDailyCrossword(score: score, date: utcFmt.string(from: date))
        }
        return OverallRatingService(rating: r)
    }
}
