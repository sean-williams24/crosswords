import SwiftUI

struct CrosswordStatsView: View {
    @EnvironmentObject var statsService: StatsService
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
                
                if statsService.stats.totalCompleted == 0 {
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
            .navigationTitle("Crossword Stats")
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
                    value: "\(statsService.stats.liveCurrentStreak)",
                    label: "Current\n Streak",
                    icon: statsService.stats.liveCurrentStreak > 0 ? "flame.fill" : nil,
                    iconColor: .orange
                )
                divider
                statCell(value: "\(statsService.stats.totalCompleted)", label: "Solved\n")
                divider
                statCell(value: "\(statsService.stats.longestStreak)", label: "Best\n Streak")
                divider
            }
            statCell(value: statsService.stats.formattedAverageTime, label: "Avg Time")
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
    
    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT GAMES")
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)
                .tracking(2)
            
            VStack(spacing: 0) {
                let history = statsService.stats.history.suffix(10).reversed()
                ForEach(Array(history.enumerated()), id: \.element.id) { index, result in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatDate(result.date))
                                .font(AppFont.body(14))
                                .foregroundColor(.appTextPrimary)
                        }
                        
                        Spacer()
                        
                        Text(result.timeSeconds.formattedTimeHHMMSS)
                            .font(AppFont.body(14))
                            .foregroundColor(.appTextSecondary)
                            .monospacedDigit()
                        
                        //                        if result.hintsUsed == 0 {
                        //                            Image(systemName: "star.fill")
                        //                                .font(.system(size: 10))
                        //                                .foregroundColor(.appAccent)
                        //                        }
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.appCorrect)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    if index < min(9, statsService.stats.history.count - 1) {
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
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
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
    CrosswordStatsView { }
        .environmentObject(CrosswordStatsView.mockService)
}

private extension CrosswordStatsView {
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
}
