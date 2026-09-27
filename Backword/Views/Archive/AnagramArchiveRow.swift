import SwiftUI

struct AnagramArchiveRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let puzzle: AnagramPuzzle
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if dynamicTypeSize > .xxxLarge {
                    VStack(alignment: .leading) {
                        details
                        HStack {
                            Spacer()
                            status
                        }
                    }
                } else {
                    HStack(spacing: 16) {
                        details
                        Spacer()
                        status
                    }
                }
            }
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private var details: some View {
        let content = AnagramArchiveRowContent(puzzle: puzzle)

        return VStack(alignment: .leading, spacing: 2) {
            Text(content.issueNumber)
                .font(AppFont.clueLabel(16))
                .foregroundStyle(Color.anagramOrange)

            Text(content.formattedDate)
                .font(AppFont.body())
                .foregroundStyle(Color.appTextPrimary)

            if content.isToday {
                Text("TODAY")
                    .font(AppFont.clueLabel(10))
                    .foregroundStyle(Color.anagramOrange)
                    .tracking(1)
            }
        }
    }

    private var status: some View {
        StatusLabelView(status: .status(for: AnagramProgress.load(date: puzzle.date)))
    }
}

struct AnagramArchiveRowContent: Equatable {
    let issueNumber: String
    let formattedDate: String
    let isToday: Bool

    init(puzzle: AnagramPuzzle, today: String = ContentReleaseCalendar().dailyDateString) {
        issueNumber = "# \(puzzle.puzzleNumber)"
        formattedDate = Self.formatDate(puzzle.date)
        isToday = puzzle.date == today
    }

    private static func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: dateString) else { return dateString }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEEE, MMM d"
        return outputFormatter.string(from: date)
    }
}

#Preview {
    AnagramArchiveRow(
        puzzle: AnagramPuzzle(
            id: "preview-anagram",
            date: "2026-09-26",
            puzzleNumber: 1,
            schemaVersion: 1,
            answer: "TRIANGLE",
            acceptedAnswers: ["INTEGRAL"],
            initialScramble: "RAGTLINE"
        ),
        onTap: {}
    )
    .padding()
    .background(Color.appBackground)
}
