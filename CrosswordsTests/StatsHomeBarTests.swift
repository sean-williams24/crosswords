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

    @Test("The dismiss-only stats footer fits without reserving a Home action",
          arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility5])
    func dismissOnly(size: DynamicTypeSize) {
        let host = UIHostingController(rootView:
            StatsHomeBar(onBackToGame: {})
                .environment(\.dynamicTypeSize, size)
        )
        let measured = host.sizeThatFits(in: CGSize(width: 320, height: 10_000))

        #expect(abs(measured.width - 320) < 0.5)
        #expect(measured.height >= 44 + 2 * AppLayout.statsHomeBarVerticalPadding)
        #expect(measured.height <= fittedSize(at: size).height + 0.5)
    }

    private func fittedSize(at size: DynamicTypeSize, width: CGFloat = 320) -> CGSize {
        let host = UIHostingController(rootView:
            StatsHomeBar(onBackToGame: {}) {}
                .environment(\.dynamicTypeSize, size)
        )
        return host.sizeThatFits(in: CGSize(width: width, height: 10_000))
    }
}
