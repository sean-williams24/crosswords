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
