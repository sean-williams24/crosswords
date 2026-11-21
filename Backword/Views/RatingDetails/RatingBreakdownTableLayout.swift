import SwiftUI

struct RatingBreakdownTableLayout<Content: View>: View {
    let isScrolling: Bool
    let isPro: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isScrolling {
            ScrollView(.horizontal, showsIndicators: true) {
                table.frame(minWidth: isPro ? 560 : 520, alignment: .leading)
            }
        } else {
            table
        }
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 0, content: content)
    }
}
