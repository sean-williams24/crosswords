import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Midword instructions")
struct MidwordInstructionsViewTests {
    @Test("Scoring rows match the five-attempt rules")
    func scoringRowsMatchAttemptRules() {
        let rules = MidwordInstructionsView.scoringRules

        #expect(rules.count == 6)
        #expect(rules[0].label == "First guess")
        #expect(rules[0].points == "5 pts")
        #expect(rules[4].label == "Fifth guess")
        #expect(rules[4].points == "1 pt")
        #expect(rules[5].label == "Not solved")
        #expect(rules[5].points == "0 pts")
    }

    @Test("Fits screen width at the largest Dynamic Type size")
    func fitsScreenAtLargestDynamicTypeSize() {
        let availableWidth: CGFloat = 320
        let host = UIHostingController(
            rootView: MidwordInstructionsView()
                .environment(\.dynamicTypeSize, .accessibility5)
        )

        let fittedSize = host.sizeThatFits(
            in: CGSize(width: availableWidth, height: 10_000)
        )

        #expect(fittedSize.width <= availableWidth + 0.5)
    }
}
