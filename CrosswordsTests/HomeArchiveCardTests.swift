import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import Backword

@MainActor
@Suite("Home Archive card")
struct HomeArchiveCardTests {
    @Test("Archive fits a grid column and keeps the game card minimum height",
          arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility5], [false, true])
    func fitsGridColumn(dynamicTypeSize: DynamicTypeSize, isProUser: Bool) {
        let card = HomeArchiveCard(isProUser: isProUser, openArchive: {})
            .environment(\.horizontalSizeClass, .regular)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .frame(width: 280)
        #if canImport(UIKit)
        let host = UIHostingController(rootView: card)
        let size = host.sizeThatFits(in: CGSize(width: 280, height: 10_000))
        #else
        let host = NSHostingView(rootView: card)
        let size = host.fittingSize
        #endif

        #expect(size.width <= 280.5)
        #expect(size.height >= AppLayout.cardHeightLarge)
    }
}
