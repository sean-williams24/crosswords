import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Backword clue layout")
struct BackwordClueViewTests {
    @Test("Short clues keep their intrinsic width so the game stack can centre them",
          arguments: [UserInterfaceSizeClass.compact, .regular])
    func shortClueDoesNotFillScreen(sizeClass: UserInterfaceSizeClass) {
        let clue = BackwordClueView(clue: "Song")
            .environment(\.horizontalSizeClass, sizeClass)
        let host = UIHostingController(rootView: clue)
        let size = host.sizeThatFits(in: CGSize(width: 1_000, height: 500))

        #expect(size.width > 0)
        #expect(size.width < 500)
        #expect(size.height > 0)
    }

    @Test("Long clues fit a narrow screen at standard and accessibility text sizes",
          arguments: [DynamicTypeSize.large, .accessibility1, .accessibility3])
    func longClueFitsScreen(dynamicTypeSize: DynamicTypeSize) {
        let clue = BackwordClueView(clue: "Transformation")
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
        let host = UIHostingController(rootView: clue)
        let size = host.sizeThatFits(in: CGSize(width: 280, height: 1_000))

        #expect(size.width <= 280.5)
        #expect(size.height > 0)
    }
}
