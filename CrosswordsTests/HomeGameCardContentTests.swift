import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Centred Home game card content")
struct HomeGameCardContentTests {
    @Test("Brand and completion details fit narrow cards as text grows",
          arguments: [DynamicTypeSize.large, .xLarge, .accessibility5])
    func contentFitsNarrowCard(dynamicTypeSize: DynamicTypeSize) {
        let card = HomeGameCardContent(minimumHeight: AppLayout.cardHeightSmall) {
            Text("QUICK\nCROSSWORD")
                .font(AppFont.clueLabel(16))
        } details: {
            VStack(alignment: .trailing) {
                Text("In Progress")
                    .font(AppFont.caption())
                Text("4 / 5    12-day streak")
                    .font(AppFont.caption())
            }
        }
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        let host = UIHostingController(rootView: card)
        let size = host.sizeThatFits(in: CGSize(width: 280, height: 10_000))

        #expect(size.width <= 280.5)
        #expect(size.height >= AppLayout.cardHeightSmall)
    }

    @Test("Cards without an issue or score retain their minimum height")
    func placeholderKeepsCardHeight() {
        let card = HomeGameCardContent(minimumHeight: AppLayout.cardHeightSmall) {
            Text("ANAGRAM")
                .font(AppFont.clueLabel(24))
        } details: {
            ProgressView()
        }
        let host = UIHostingController(rootView: card)
        let size = host.sizeThatFits(in: CGSize(width: 280, height: 10_000))

        #expect(size.width <= 280.5)
        #expect(size.height >= AppLayout.cardHeightSmall)
    }
}
