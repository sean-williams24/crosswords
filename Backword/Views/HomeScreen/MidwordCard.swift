import SwiftUI

struct MidwordCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let puzzle: MidwordPuzzle?
    let progress: MidwordProgress?
    let isLoading: Bool
    let loadFailed: Bool
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
        Group {
            if AnagramHomeCardLayout.usesStackedLayout(for: dynamicTypeSize) {
                VStack(alignment: .leading, spacing: AnagramHomeCardLayout.columnSpacing) {
                    identityView
                    detailsView
                }
            } else {
                HStack(alignment: .top, spacing: AnagramHomeCardLayout.columnSpacing) {
                    identityView
                    detailsView
                }
            }
        }
        .padding(.horizontal, AnagramHomeCardLayout.horizontalPadding)
        .padding(.vertical, AnagramHomeCardLayout.verticalPadding)
        .foregroundStyle(Color.midwordHomeCardForeground)
        .frame(maxWidth: .infinity, minHeight: appLayout.cardHeight)
        .background(Color.midwordAccent)
    }

    private var identityView: some View {
        VStack(alignment: .leading, spacing: AnagramHomeCardLayout.identitySpacing) {
            Text("MIDWORD")
                .font(AppFont.clueLabel(appLayout.isiPad ? 28 : 24))
                .tracking(3)
                .lineLimit(1)
                .minimumScaleFactor(0.35)

            if let puzzle {
                HomeCardIssueNumber(issueNumber: puzzle.puzzleNumber, color: .midwordHomeCardForeground)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var detailsView: some View {
        VStack(alignment: .trailing, spacing: AnagramHomeCardLayout.contentSpacing) {
            Spacer(minLength: AnagramHomeCardLayout.minimumContentSpacing)

            if puzzle != nil {
                statusLabel
                HStack(spacing: AnagramHomeCardLayout.statsSpacing) {
                    scoreLabel
                }
            } else if isLoading {
                ProgressView().tint(.midwordHomeCardForeground)
            } else if loadFailed {
                Button("Try again", action: retry)
                    .font(AppFont.caption().bold())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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
