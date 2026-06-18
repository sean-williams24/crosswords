//  StatsView.swift

import SwiftUI

struct StatsView: View {
    private var currentStreak: Int
    private var longestStreak: Int
    private var winRate: Int?
    private var totalCompleted: Int
    private var averageTimeSeconds: String?

    init(stats: BackwordStats) {
        currentStreak = stats.currentStreak
        totalCompleted = stats.gamesWon
        longestStreak = stats.longestStreak
        winRate = stats.winRate
    }

    init(stats: UserStats, isWeekly: Bool) {
        currentStreak = stats.currentStreak(isWeekly: isWeekly)
        longestStreak = stats.longestStreak(isWeekly: isWeekly)
        totalCompleted = stats.totalCompleted(isWeekly: isWeekly)
        averageTimeSeconds = stats.formattedAverageTime(isWeekly: isWeekly)
    }

    var body: some View {
        summaryRow
    }

    @ViewBuilder
    private var summaryRow: some View {
        ViewThatFits {
            horizontalSummaryRowContent
            verticalSummaryRowContent
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .strokeBorder(.clear)
        )
    }

    private var verticalSummaryRowContent: some View {
        VStack {
            HStack(spacing: 0) {
                streakCell
                divider
                totalCompletedCell
            }

            HStack(spacing: 0) {
                longestStreakCell
                divider
                winRateCell
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var horizontalSummaryRowContent: some View {
        VStack {
            HStack(spacing: 8) {
                streakCell
                divider
                totalCompletedCell
                divider
                longestStreakCell
            }
            winRateCell
        }
    }

    private var streakCell: some View {
        statCell(
            value: "\(currentStreak)",
            label: "Current\n Streak"
        )
    }

    @ViewBuilder
    private var totalCompletedCell: some View {
        statCell(value: "\(totalCompleted)", label: "Total\nSolved")
    }

    private var longestStreakCell: some View {
        statCell(value: "\(longestStreak)", label: "Best\n Streak")
    }

    @ViewBuilder
    private var winRateCell: some View {
        if let winRate {
            statCell(value: "\(winRate)%", label: "Win Rate")
        } else if let averageTimeSeconds {
            statCell(value: averageTimeSeconds, label: "Avg Time")
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.appGridLine.opacity(0.5))
            .frame(width: 1, height: 40)
    }

    private func statCell(
        value: String,
        label: String
    ) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.header(28))
                .foregroundColor(.appTextPrimary)
                .fixedSize(horizontal: true, vertical: false)
            Text(label)
                .font(AppFont.clueLabel(11))
                .foregroundColor(.appTextSecondary)
                .tracking(1)
                .lineLimit(2)
                .fixedSize(horizontal: true, vertical: false)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    StatsView(stats: BackwordStats())
    StatsView(stats: UserStats(), isWeekly:  false)
}
