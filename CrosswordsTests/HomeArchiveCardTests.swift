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
    @Test("The Archive title uses at most one line beside its icon at larger text sizes",
          arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility1, .accessibility5],
          [CGFloat(180), 280])
    func titleStaysOnOneLine(dynamicTypeSize: DynamicTypeSize, width: CGFloat) {
        let contentWidth = width - 2 * AppLayout.screenPadding
        let title = HStack(spacing: AppLayout.homeArchiveContentSpacing) {
            Image(systemName: "archivebox")
            Text("ARCHIVE").fixedSize()
        }
        .font(AppFont.clueLabel(AppLayout.homeArchiveTitleSize))
        .fixedSize()
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        let description = Text("Unlock the full archive for all five games")
            .font(AppFont.caption())
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
        let maximumHeight = max(
            AppLayout.cardHeightSmall,
            measuredSize(title, width: contentWidth).height
                + AppLayout.homeArchiveContentSpacing
                + measuredSize(description, width: contentWidth).height
                + 2 * AppLayout.screenPadding
        )
        let card = HomeArchiveCard(isProUser: false, openArchive: {})
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
        let size = measuredSize(card, width: width)

        #expect(size.width <= width + 0.5)
        #expect(size.height <= maximumHeight + 0.5)
    }

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

    private func measuredSize(_ content: some View, width: CGFloat) -> CGSize {
        #if canImport(UIKit)
        return UIHostingController(rootView: content)
            .sizeThatFits(in: CGSize(width: width, height: 10_000))
        #else
        return NSHostingView(rootView: content.frame(width: width)).fittingSize
        #endif
    }
}
