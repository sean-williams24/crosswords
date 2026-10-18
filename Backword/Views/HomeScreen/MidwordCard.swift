import SwiftUI

struct MidwordCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let puzzle: MidwordPuzzle?
    let progress: MidwordProgress?
    let isLoading: Bool
    let loadFailed: Bool
    var currentStreak: Int = 0
    let retry: () -> Void
    let play: () -> Void

    private var appLayout: AppLayout {
        AppLayout(sizeClass: sizeClass)
    }

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
        HomeGameCardContent(minimumHeight: appLayout.cardHeight) {
            MidwordHomeCardLogo()
        } details: {
            detailsView
        } header: {
            HomeGameCardHeader(spacing: AnagramHomeCardLayout.statsSpacing) {
                EmptyView()
            } streak: {
                StreakButton(streak: currentStreak, textColor: .midwordHomeCardForeground)
            }
        }
        .foregroundStyle(Color.midwordHomeCardForeground)
        .background(Color.midwordAccent)
    }

    @ViewBuilder
    private var issueLabel: some View {
        if let issueNumber = puzzle?.puzzleNumber {
            HomeCardIssueNumber(issueNumber: issueNumber, color: .midwordHomeCardForeground)
        }
    }

    private var detailsView: some View {
        HomeGameCardFooter(spacing: AnagramHomeCardLayout.statsSpacing) {
            if puzzle != nil { scoreLabel }
        } status: {
            if puzzle != nil {
                statusLabel
            } else if isLoading {
                ProgressView().tint(.midwordHomeCardForeground)
            } else if loadFailed {
                Button("Try again", action: retry)
                    .font(AppFont.caption().bold())
            }
        } issue: {
            issueLabel
        }
    }

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.label)
                .font(AppFont.clueLabel(11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.midwordHomeCardForeground.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
    }

    @ViewBuilder
    private var scoreLabel: some View {
        if let progress, progress.isComplete {
            HStack(spacing: 4) {
                Text("\(progress.releaseDateScore)")
                    .font(AppFont.header(24))
                Text("/ 5")
                    .font(AppFont.header(12))
                    .opacity(0.7)
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
