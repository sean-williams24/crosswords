import SwiftUI

enum HomeCardIssueNumberLayout {
    static let horizontalInset: CGFloat = 14
    static let topInset: CGFloat = 10
}

struct HomeCardIssueNumber: View {
    let issueNumber: Int
    var color: Color = .appTextPrimary

    var body: some View {
        Text(HomeCardIssueNumberContent.label(for: issueNumber))
            .font(AppFont.clueLabel(AppLayout.homeCardIssueNumberFontSize))
            .foregroundColor(color.opacity(0.58))
            .fixedSize(horizontal: true, vertical: false)
            // The label occupies the cards' existing top whitespace. Capping
            // its Dynamic Type size prevents it from intruding on card content.
            .dynamicTypeSize(.xSmall ... .xLarge)
            .accessibilityLabel(HomeCardIssueNumberContent.accessibilityLabel(for: issueNumber))
    }
}

enum HomeCardIssueNumberContent {
    static func label(for issueNumber: Int) -> String {
        "#\(issueNumber)"
    }

    static func accessibilityLabel(for issueNumber: Int) -> String {
        "Issue #\(issueNumber)"
    }
}
