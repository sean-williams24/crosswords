import SwiftUI

struct MidwordArchiveRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var ratingService: OverallRatingService
    @State private var showGame = false
    @State private var progress: MidwordProgress?

    let puzzle: MidwordPuzzle

    var body: some View {
        Button {
            showGame = true
        } label: {
            dynamicContent
                .frame(minHeight: 50)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.appSurface)
                .cornerRadius(AppLayout.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: $showGame) {
            MidwordView(puzzle: puzzle)
                .environmentObject(ratingService)
        }
        .onAppear(perform: refresh)
        .onChange(of: showGame) { _, isPresented in
            guard !isPresented else { return }
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .midwordProgressDidChange)) { _ in
            refresh()
        }
    }

    @ViewBuilder
    private var dynamicContent: some View {
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

    private var details: some View {
        let content = MidwordArchiveRowContent(puzzle: puzzle)

        return VStack(alignment: .leading, spacing: 2) {
            ArchiveIssueDateView(
                issueNumber: content.issueNumber,
                formattedDate: content.formattedDate,
                accentColor: .midwordAccent
            )

            if content.isToday {
                Text("TODAY")
                    .font(AppFont.clueLabel(10))
                    .foregroundStyle(Color.midwordAccent)
                    .tracking(1)
            }

            Text(content.clue.uppercased())
                .font(AppFont.clueLabel(16))
                .foregroundStyle(Color.midwordAccent)
        }
    }

    private var status: some View {
        StatusLabelView(status: .midwordStatus(for: progress))
    }

    private func refresh() {
        progress = MidwordProgress.load(date: puzzle.date)
    }
}

struct MidwordArchiveRowContent: Equatable {
    let clue: String
    let formattedDate: String
    let issueNumber: String
    let isToday: Bool

    init(puzzle: MidwordPuzzle, today: String = ContentReleaseCalendar().dailyDateString) {
        clue = "\(puzzle.firstWord)  ·  ?  ·  \(puzzle.secondWord)"
        formattedDate = Self.formatDate(puzzle.date)
        issueNumber = "# \(puzzle.puzzleNumber)"
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
    MidwordArchiveRow(
        puzzle: MidwordPuzzle(
            id: "preview-midword",
            date: "2026-10-01",
            puzzleNumber: 42,
            firstWord: "PAGE",
            secondWord: "CASE",
            answer: "TURN",
            alternatives: []
        )
    )
    .environmentObject(OverallRatingService())
    .padding()
    .background(Color.appBackground)
}
