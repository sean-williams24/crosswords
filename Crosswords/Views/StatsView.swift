import SwiftUI

struct StatsView: View {
    @EnvironmentObject var statsService: StatsService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                if statsService.stats.totalCompleted == 0 {
                    emptyState
                } else {
                    statsContent
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // Primary stat: current streak
            VStack(spacing: 4) {
                Text("\(statsService.stats.currentStreak)")
                    .font(AppFont.statNumber())
                    .foregroundColor(.appAccent)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("CURRENT STREAK")
                        .font(AppFont.clueLabel(11))
                        .foregroundColor(.appTextSecondary)
                        .tracking(2)
                }
            }

            // Secondary stats grid
            HStack(spacing: 0) {
                statBox(
                    value: "\(statsService.stats.longestStreak)",
                    label: "BEST\nSTREAK"
                )
                statDivider
                statBox(
                    value: "\(statsService.stats.totalCompleted)",
                    label: "PUZZLES\nSOLVED"
                )
                statDivider
                statBox(
                    value: statsService.stats.formattedAverageTime,
                    label: "AVG\nTIME"
                )
            }
            .padding(.vertical, 20)
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)
            .padding(.horizontal, AppLayout.screenPadding)

            // Recent history
            if !statsService.stats.history.isEmpty {
                recentHistory
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(AppFont.header(24))
                .foregroundColor(.appTextPrimary)
            Text(label)
                .font(AppFont.clueLabel(9))
                .foregroundColor(.appTextSecondary)
                .tracking(1.5)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.appGridLine)
            .frame(width: 1, height: 50)
    }

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT")
                .font(AppFont.clueLabel(11))
                .foregroundColor(.appTextSecondary)
                .tracking(2)
                .padding(.horizontal, AppLayout.screenPadding)

            VStack(spacing: 0) {
                ForEach(statsService.stats.history.suffix(5).reversed()) { result in
                    HStack {
                        Text(result.puzzleId)
                            .font(AppFont.body(14))
                            .foregroundColor(.appTextPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(formatTime(result.timeSeconds))
                            .font(AppFont.body(14))
                            .foregroundColor(.appTextSecondary)

                        if result.hintsUsed == 0 {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.appAccent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if result.id != statsService.stats.history.last?.id {
                        Divider()
                            .background(Color.appGridLine)
                    }
                }
            }
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)
            .padding(.horizontal, AppLayout.screenPadding)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece")
                .font(.system(size: 48))
                .foregroundColor(.appTextSecondary)
            Text("No puzzles completed yet")
                .font(AppFont.body())
                .foregroundColor(.appTextSecondary)
            Text("Complete your first puzzle to see stats")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary.opacity(0.7))
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
