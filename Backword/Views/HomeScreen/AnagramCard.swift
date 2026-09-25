import SwiftUI

struct AnagramCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    let puzzle: AnagramPuzzle
    let isReview: Bool
    let summary: AnagramHomeCardSummary
    let open: () -> Void

    private var appLayout: AppLayout {
        AppLayout(sizeClass: sizeClass)
    }

    var body: some View {
        Button(action: open) {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("ANAGRAM")
                        .font(AppFont.clueLabel(appLayout.isiPad ? 28 : 24))
                        .tracking(3)

                    Text(isReview ? "Sample puzzle" : "\(puzzle.length) letters")
                        .font(AppFont.caption())

                    statusLabel
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 8)

                HStack {
                    scoreLabel
                    Spacer(minLength: 2)
                    if summary.streak > 0 { streakLabel }
                }
                .padding(.horizontal, HomeCardStreakLayout.streakButtonEdgeInset)
                .padding(.bottom, 10)
            }
            .foregroundStyle(Color.anagramOnOrange)
            .frame(maxWidth: .infinity, minHeight: appLayout.cardHeight)
            .background(Color.anagramOrange)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
            .overlay(alignment: .topTrailing) {
                if isReview {
                    Text("REVIEW")
                        .font(AppFont.clueLabel(AppLayout.homeCardIssueNumberFontSize))
                        .foregroundStyle(Color.anagramOnOrange.opacity(0.58))
                        .padding(.trailing, HomeCardIssueNumberLayout.horizontalInset)
                        .padding(.top, HomeCardIssueNumberLayout.topInset)
                } else {
                    HomeCardIssueNumber(issueNumber: puzzle.puzzleNumber, color: .anagramOnOrange)
                        .padding(.trailing, HomeCardIssueNumberLayout.horizontalInset)
                        .padding(.top, HomeCardIssueNumberLayout.topInset)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilitySummary)
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
        let title = isReview ? "Anagram review puzzle" : "Anagram issue \(puzzle.puzzleNumber)"
        let points = summary.score.map { ", \($0) of 5 points" } ?? ""
        let streak = summary.streak > 0 ? ", \(summary.streak)-day streak" : ""
        return "\(title), \(statusText)\(points)\(streak). Double tap to open."
    }
}
