import SwiftUI

struct ArchivePuzzleRow: View {
    let puzzle: Puzzle
    let isWeekly: Bool
    let onTap: () -> Void

    var body: some View {
        let fraction = progressFraction

        Button(action: onTap) {
            VStack(spacing: 0) {
                ViewThatFits {
                    HStack(spacing: 16) {
                        rowContent
                    }
                    VStack(alignment: .leading) {
                        rowContent
                    }
                }
                .frame(minHeight: 50)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if fraction > 0 {
                    GeometryReader { geo in
                        Capsule()
                            .fill(progressColor(for: fraction))
                            .frame(width: geo.size.width * fraction, height: 3)
                            .animation(.easeOut(duration: 0.6), value: fraction)
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDate(puzzle.date))
                    .font(AppFont.body())
                    .foregroundColor(.appTextPrimary)

                if isToday(puzzle.date) {
                    Text("TODAY")
                        .font(AppFont.clueLabel(10))
                        .foregroundColor(.appAccent)
                        .tracking(1)
                }
            }

            Spacer()

            StatusLabelView(status: .status(for: archiveEntry, isWeekly: isWeekly))
        }
    }

    private var archiveEntry: ArchiveEntry {
        ArchiveEntry(id: puzzle.id, puzzleNumber: puzzle.puzzleNumber, date: puzzle.date)
    }

    private var progressFraction: CGFloat {
        guard let progress = UserProgress.load(puzzleId: puzzle.id) else { return 0 }
        if progress.isComplete { return 1.0 }

        let filled = progress.entries.flatMap { $0 }.compactMap { $0 }.count
        guard filled > 0 else { return 0 }

        let fillable = puzzle.cells.flatMap { $0 }.filter { !$0.isBlack }.count
        guard fillable > 0 else { return 0 }
        return min(CGFloat(filled) / CGFloat(fillable), 1.0)
    }

    private func progressColor(for fraction: CGFloat) -> Color {
        if fraction >= 1.0 { return .appCorrect }
        return .appAccent
    }

    private func formattedDate(_ dateString: String) -> String {
        let inputFmt = DateFormatter()
        inputFmt.dateFormat = "yyyy-MM-dd"
        guard let date = inputFmt.date(from: dateString) else { return dateString }

        let outputFmt = DateFormatter()
        outputFmt.dateFormat = "EEEE, MMM d"
        return outputFmt.string(from: date)
    }

    private func isToday(_ dateString: String) -> Bool {
        dateString == ContentReleaseCalendar().dailyDateString
    }
}

#Preview {
    ArchivePuzzleRow(puzzle: .sample, isWeekly: false) {}
}
