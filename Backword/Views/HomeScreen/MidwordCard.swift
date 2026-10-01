import SwiftUI

struct MidwordCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let puzzle: MidwordPuzzle?
    let progress: MidwordProgress?
    let isLoading: Bool
    let loadFailed: Bool
    let retry: () -> Void
    let play: () -> Void

    var body: some View {
        Group {
            if let puzzle {
                Button(action: play) { cardContent }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Midword number \(puzzle.puzzleNumber): \(puzzle.firstWord), missing word, \(puzzle.secondWord). \(status.label). Play")
            } else {
                cardContent
            }
        }
        .cornerRadius(AppLayout.cardCornerRadius)
    }

    private var cardContent: some View {
        VStack(spacing: 14) {
            Text("MIDWORD")
                .font(AppFont.header(26))

            if puzzle != nil {
                StatusLabelView(status: status, textStyle: .primary)
                    .environment(\.colorScheme, .light)
                if let progress, progress.isComplete {
                    Text("\(progress.releaseDateScore) / 5 points")
                        .font(AppFont.caption())
                }
            } else if isLoading {
                ProgressView().tint(.midwordOnAccent)
            } else if loadFailed {
                Button("Try again", action: retry)
                    .font(AppFont.body())
            }
        }
        .foregroundColor(.midwordOnAccent)
        .multilineTextAlignment(.center)
        .padding(AppLayout.screenPadding)
        .frame(maxWidth: .infinity, minHeight: AppLayout(sizeClass: sizeClass).cardHeight)
        .background(Color.midwordAccent)
        .overlay(alignment: .topTrailing) {
            if let puzzle {
                HomeCardIssueNumber(issueNumber: puzzle.puzzleNumber, color: .midwordOnAccent)
                    .padding(.trailing, HomeCardIssueNumberLayout.horizontalInset)
                    .padding(.top, HomeCardIssueNumberLayout.topInset)
            }
        }
    }

    private var status: PuzzleStatus {
        PuzzleStatus.midwordStatus(for: progress)
    }
}

#Preview {
    MidwordCard(
        puzzle: MidwordPuzzle(
            id: "midword-preview",
            date: "2026-10-01",
            puzzleNumber: 1,
            firstWord: "BANK",
            secondWord: "BOOK",
            answer: "NOTE",
            alternatives: []
        ),
        progress: nil,
        isLoading: false,
        loadFailed: false,
        retry: {},
        play: {}
    )
    .padding(AppLayout.screenPadding)
}
