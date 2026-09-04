import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Backword rules update notice layout")
struct BackwordRulesUpdateNoticeTests {
    @Test("Fills the available horizontal width")
    func fillsAvailableWidth() {
        let availableWidth: CGFloat = 320
        let host = UIHostingController(rootView: BackwordRulesUpdateNotice())

        let fittedSize = host.sizeThatFits(
            in: CGSize(width: availableWidth, height: 1_000)
        )

        #expect(abs(fittedSize.width - availableWidth) < 0.5)
    }

    @Test("Uses equal 16 point content insets")
    func usesExpectedContentPadding() {
        #expect(BackwordRulesUpdateNotice.contentPadding == 16)
    }
}

@MainActor
@Suite("Backword instructions layout")
struct BackwordInstructionsLayoutTests {
    @Test("Easy mode toggle title reflects its state")
    func easyModeToggleTitleReflectsState() {
        #expect(BackwordModeToggle.title(isEnabled: false) == "Easy Mode - Off")
        #expect(BackwordModeToggle.title(isEnabled: true) == "Easy Mode - On")
    }

    @Test("Fits screen width at the largest Dynamic Type size")
    func fitsScreenAtLargestDynamicTypeSize() {
        let availableWidth: CGFloat = 320
        let host = UIHostingController(
            rootView: BackwordInstructionsContentView()
                .environment(\.dynamicTypeSize, .accessibility5)
        )

        let fittedSize = host.sizeThatFits(
            in: CGSize(width: availableWidth, height: 10_000)
        )

        #expect(fittedSize.width <= availableWidth + 0.5)
    }

    @Test("Easy rules fit screen width at the largest Dynamic Type size")
    func easyRulesFitScreenAtLargestDynamicTypeSize() {
        let availableWidth: CGFloat = 320
        let host = UIHostingController(
            rootView: BackwordInstructionsContentView(mode: .constant(.easy))
                .environment(\.dynamicTypeSize, .accessibility5)
        )

        let fittedSize = host.sizeThatFits(
            in: CGSize(width: availableWidth, height: 10_000)
        )

        #expect(fittedSize.width <= availableWidth + 0.5)
    }
}

@MainActor
@Suite("Backword clue explainer layout")
struct BackwordClueExplainerLayoutTests {
    @Test("White container fills the available horizontal width")
    func fillsAvailableWidth() {
        let availableWidth: CGFloat = 320
        let host = UIHostingController(rootView: BackwordClueExplainerView())

        let fittedSize = host.sizeThatFits(
            in: CGSize(width: availableWidth, height: 1_000)
        )

        #expect(abs(fittedSize.width - availableWidth) < 0.5)
    }
}
