import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Player Profile rating breakdown layout")
struct RatingBreakdownTableLayoutTests {
    @Test("The Date header and rows keep the same leading inset",
          arguments: [DynamicTypeSize.small, .medium, .accessibility5], [false, true])
    func dateColumnInset(textSize: DynamicTypeSize, isPro: Bool) {
        let isScrolling = textSize >= .medium
        let dateHeader = UIView()
        let dateCell = UIView()
        let host = UIHostingController(rootView:
            RatingBreakdownTableLayout(isScrolling: isScrolling, isPro: isPro) {
                TestRow(dateView: dateHeader, isScrolling: isScrolling, scoreColumnsWidth: 325)
                Divider()
                TestRow(dateView: dateCell, isScrolling: isScrolling, scoreColumnsWidth: 350)
            }
            .environment(\.dynamicTypeSize, textSize)
            .environment(\.layoutDirection, .leftToRight)
        )

        withLaidOutHostingController(host, size: CGSize(width: 402, height: 100)) {
            for view in [dateHeader, dateCell] {
                #expect(view.isDescendant(of: host.view))
                let frame = view.convert(view.bounds, to: host.view)
                #expect(abs(frame.minX - AppLayout.statsHistoryRowInset) < 0.5)
            }
        }
    }

    private struct TestRow: View {
        let dateView: UIView
        let isScrolling: Bool
        @ScaledMetric private var scoreColumnsWidth: CGFloat

        init(dateView: UIView, isScrolling: Bool, scoreColumnsWidth: CGFloat) {
            self.dateView = dateView
            self.isScrolling = isScrolling
            _scoreColumnsWidth = ScaledMetric(wrappedValue: scoreColumnsWidth)
        }

        var body: some View {
            HStack(spacing: 0) {
                DateColumnMarker(view: dateView).frame(width: 40, height: 20)
                    .frame(maxWidth: isScrolling ? nil : .infinity, alignment: .leading)
                Color.clear.frame(width: scoreColumnsWidth, height: 20)
            }
            .padding(.leading, AppLayout.statsHistoryRowInset)
        }
    }

    private struct DateColumnMarker: UIViewRepresentable {
        let view: UIView

        func makeUIView(context: Context) -> UIView { view }
        func updateUIView(_ uiView: UIView, context: Context) {}
    }
}
