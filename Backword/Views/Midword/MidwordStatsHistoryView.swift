import SwiftUI

struct MidwordStatsHistoryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let rows: [MidwordStatsHistoryRow]

    private var scoreColumnWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? AppLayout.statsHistoryAccessibleScoreColumnWidth
            : AppLayout.statsHistoryScoreColumnWidth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST 14 DAYS")
                .font(AppFont.clueLabel(12))
                .foregroundStyle(Color.midwordAccent)
                .tracking(2)
                .padding(.horizontal, AppLayout.screenPadding)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Date").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Score").frame(width: scoreColumnWidth)
                    Text("Guesses").frame(width: AppLayout.statsHistoryTimeColumnWidth)
                }
                .font(AppFont.clueLabel(10))
                .foregroundStyle(Color.midwordAccent)
                .tracking(1)
                .padding(.leading, AppLayout.statsHistoryRowInset)
                .padding(.vertical, 8)

                separator

                ForEach(Array(rows.enumerated()), id: \.element.dateStr) { index, row in
                    historyRow(row)
                    if index < rows.count - 1 { separator }
                }
            }
            .background(Color.midwordText.opacity(0.08))
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var separator: some View {
        Divider().overlay(Color.midwordAccent.opacity(0.22))
    }

    private func historyRow(_ row: MidwordStatsHistoryRow) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(AppFont.body(13))
                    .foregroundStyle(row.isToday ? Color.midwordAccent : Color.midwordText)
                if row.isToday { status("TODAY") }
                switch row.outcome {
                case .solved: status("SOLVED")
                case .failed: status("FAILED")
                case .unplayed, .inProgress: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(row.score)")
                .font(AppFont.clueLabel(12))
                .foregroundStyle(row.score > 0 ? Color.midwordOnAccent : Color.midwordAccent.opacity(0.65))
                .frame(width: AppLayout.statsHistoryScoreChipSize, height: AppLayout.statsHistoryScoreChipSize)
                .background(row.score > 0 ? Color.midwordAccent : Color.midwordAccent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cellCornerRadius))
                .frame(width: scoreColumnWidth)

            Group {
                if let guessCount = row.guessCount {
                    Text("\(guessCount)/5")
                } else {
                    Text("–").foregroundStyle(Color.midwordAccent.opacity(0.5))
                }
            }
            .font(AppFont.body(13))
            .foregroundStyle(Color.midwordAccent)
            .frame(width: AppLayout.statsHistoryTimeColumnWidth)
        }
        .padding(.leading, AppLayout.statsHistoryRowInset)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func status(_ title: String) -> some View {
        Text(title)
            .font(AppFont.clueLabel(9))
            .foregroundStyle(Color.midwordAccent)
            .tracking(1)
    }
}
