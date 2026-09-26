import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Anagram instructions")
struct AnagramInstructionsContentViewTests {
    @Test("Scoring rows match the game thresholds")
    func scoringRowsMatchGameThresholds() {
        let rules = AnagramInstructionsContentView.scoringRules

        #expect(rules.count == 6)
        #expect(rules[0].label == "Under 30 seconds")
        #expect(rules[0].points == "5 pts")
        #expect(rules[4].label == "3:00 or longer")
        #expect(rules[4].points == "1 pt")
        #expect(rules[5].label == "Give up")
        #expect(rules[5].points == "0 pts")
    }

    @Test("Fits screen width at the largest Dynamic Type size")
    func fitsScreenAtLargestDynamicTypeSize() {
        let availableWidth: CGFloat = 320
        let host = UIHostingController(
            rootView: AnagramInstructionsContentView()
                .environment(\.dynamicTypeSize, .accessibility5)
        )

        let fittedSize = host.sizeThatFits(
            in: CGSize(width: availableWidth, height: 10_000)
        )

        #expect(fittedSize.width <= availableWidth + 0.5)
    }
}
