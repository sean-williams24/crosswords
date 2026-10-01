import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Anagram action button layout")
struct AnagramActionButtonTests {
    @Test("Gameplay button rows retain their height at accessibility text sizes")
    func actionRowsCapDynamicType() {
        for titles in [["Undo", "Restart", "Shuffle"], ["Hint", "Give up"], ["Start"]] {
            let largeSize = rowSize(titles: titles, dynamicTypeSize: .large)
            let accessibilitySize = rowSize(titles: titles, dynamicTypeSize: .accessibility5)

            #expect(abs(accessibilitySize.height - largeSize.height) < 0.5)
            #expect(accessibilitySize.width <= 320)
        }
    }

    private func rowSize(titles: [String], dynamicTypeSize: DynamicTypeSize) -> CGSize {
        let row = HStack(spacing: 10) {
            ForEach(titles, id: \.self) { title in
                AnagramActionButton(title: title, action: {})
            }
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        let host = UIHostingController(rootView: row)
        return host.sizeThatFits(in: CGSize(width: 320, height: 1_000))
    }
}
