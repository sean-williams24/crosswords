import SwiftUI

struct RatingScoringGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("HOW SCORING WORKS")
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)
                .tracking(2)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)

            VStack(alignment: .leading, spacing: 14) {
                Divider().background(Color.appGridLine)

                ScoringRuleView.crossword()
                    .padding(.leading, 8)

                Text("- 1 point deducted for every 3 hints used")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
                    .padding(.leading, 8)

                Divider().background(Color.appGridLine.opacity(0.5))

                ScoringRuleView.backword()
                    .padding(.leading, 8)

                Divider().background(Color.appGridLine.opacity(0.5))

                ScoringRuleView.anagram()
                    .padding(.leading, 8)

                Divider().background(Color.appGridLine.opacity(0.5))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Rolling 14-day window")
                        .font(AppFont.clueLabel(13))
                        .foregroundColor(.appTextPrimary)
                        .padding(.leading, 8)

                    Text("Your rating reflects only the last 14 days. Skip a day and it scores 0, so play every day to keep your rating up.")
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                        .padding(.leading, 8)
                }
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
    }
}
