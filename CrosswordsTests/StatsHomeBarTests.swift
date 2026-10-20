import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Stats Home bar")
struct StatsHomeBarTests {
    @Test("The footer fits phone and tablet sheets with a full-size touch target",
          arguments: [CGFloat(320), 390, 768], [DynamicTypeSize.xSmall, .large, .xxxLarge, .accessibility5])
    func fitsSheet(width: CGFloat, size: DynamicTypeSize) {
        let barSize = fittedSize(at: size, width: width)

        #expect(abs(barSize.width - width) < 0.5)
        #expect(barSize.height - 2 * AppLayout.statsHomeBarVerticalPadding >= 44)

        let label = Text("HOME")
            .font(AppFont.body())
            .environment(\.dynamicTypeSize, size)
        let labelSize = UIHostingController(rootView: label)
            .sizeThatFits(in: CGSize(width: width - 2 * AppLayout.screenPadding, height: 10_000))

        #expect(barSize.height >= labelSize.height + 2 * AppLayout.statsHomeBarVerticalPadding)
    }

    @Test("Home stays readable as Dynamic Type grows without a fixed-height footer")
    func growsWithText() {
        let small = fittedSize(at: .xSmall)
        let standard = fittedSize(at: .large)
        let accessible = fittedSize(at: .accessibility5)

        #expect(small.height <= standard.height)
        #expect(standard.height < accessible.height)
    }

    private func fittedSize(at size: DynamicTypeSize, width: CGFloat = 320) -> CGSize {
        let host = UIHostingController(rootView:
            StatsHomeBar {}
                .environment(\.dynamicTypeSize, size)
        )
        return host.sizeThatFits(in: CGSize(width: width, height: 10_000))
    }
}
