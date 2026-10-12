import SwiftUI

struct HomeGameCardFooter<Score: View, Status: View, Issue: View>: View {
    let spacing: CGFloat
    @ViewBuilder var score: () -> Score
    @ViewBuilder var status: () -> Status
    @ViewBuilder var issue: () -> Issue

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: spacing) {
                ZStack(alignment: .bottomLeading) {
                    score()
                    issue().hidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                status()
                    .fixedSize(horizontal: true, vertical: false)
                ZStack(alignment: .bottomTrailing) {
                    issue()
                    score().hidden()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            VStack(alignment: .center, spacing: spacing) {
                HStack(alignment: .bottom, spacing: spacing) {
                    score()
                    Spacer(minLength: spacing)
                    issue()
                }
                status()
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }
}

extension HomeGameCardFooter where Issue == EmptyView {
    init(
        spacing: CGFloat,
        @ViewBuilder score: @escaping () -> Score,
        @ViewBuilder status: @escaping () -> Status
    ) {
        self.spacing = spacing
        self.score = score
        self.status = status
        self.issue = { EmptyView() }
    }
}
