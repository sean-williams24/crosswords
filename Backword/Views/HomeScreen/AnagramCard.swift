import SwiftUI

struct AnagramCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    let puzzle: AnagramPuzzle
    let summary: AnagramHomeCardSummary
    let open: () -> Void

    private var appLayout: AppLayout {
        AppLayout(sizeClass: sizeClass)
    }

    var body: some View {
        Button(action: open) {
            HomeGameCardContent(minimumHeight: appLayout.cardHeight) {
                identityView
            } details: {
                detailsView
            } header: {
                HomeGameCardHeader(spacing: AnagramHomeCardLayout.statsSpacing) {
                    EmptyView()
                } streak: {
                    if summary.streak > 0 { streakLabel }
                }
            }
            .foregroundStyle(Color.anagramOnOrange)
            .background(Color.anagramHomeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var identityView: some View {
        Text("ANAGRAM")
            .font(AppFont.clueLabel(appLayout.isiPad ? 28 : 24))
            .tracking(3)
            .padding(.trailing, -3)
            .lineLimit(1)
            .minimumScaleFactor(0.35)
    }

    private var issueLabel: some View {
        HomeCardIssueNumber(issueNumber: puzzle.puzzleNumber, color: .anagramOnOrange)
    }

    private var detailsView: some View {
        HomeGameCardFooter(spacing: AnagramHomeCardLayout.statsSpacing) {
            scoreLabel
        } status: {
            statusLabel
        } issue: {
            issueLabel
        }
    }

    private var statusLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption2)
            Text(statusText)
                .font(AppFont.clueLabel(11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.anagramOnOrange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
    }

    @ViewBuilder
    private var scoreLabel: some View {
        if let score = summary.score {
            HStack(spacing: 4) {
                Text("\(score)")
                    .font(AppFont.header(24))
                Text("/ 5")
                    .font(AppFont.header(12))
                    .opacity(0.7)
            }
        }
    }

    private var streakLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.caption)
            Text("\(summary.streak)")
                .font(AppFont.clueLabel(12))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.anagramOnOrange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .accessibilityLabel("\(summary.streak)-day Anagram streak")
    }

    private var statusText: String {
        switch summary.status {
        case .new: "New"
        case .inProgress: "In Progress"
        case .solved: "Solved"
        case .finished: "Finished"
        case .gaveUp: "Gave up"
        }
    }

    private var statusIcon: String {
        switch summary.status {
        case .new: "circle"
        case .inProgress: "pencil.circle"
        case .solved, .finished: "checkmark.circle.fill"
        case .gaveUp: "xmark.circle.fill"
        }
    }

    private var accessibilitySummary: String {
        let points = summary.score.map { ", \($0) of 5 points" } ?? ""
        let streak = summary.streak > 0 ? ", \(summary.streak)-day streak" : ""
        return "Anagram issue \(puzzle.puzzleNumber), \(statusText)\(points)\(streak). Double tap to open."
    }
}

enum AnagramHomeCardLayout {
    static let horizontalPadding: CGFloat = 18
    static let verticalPadding: CGFloat = 12
    static let identitySpacing: CGFloat = 4
    static let contentSpacing: CGFloat = 8
    static let statsSpacing: CGFloat = 8
}
