import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import Backword

@MainActor
@Suite("Equal Home card sizes")
struct HomeGameCardsGridTests {
    @Test("All game and Archive cards fill the tallest card's height as text grows",
          arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility1, .accessibility5],
          [CGFloat(580), 900])
    func equalCardSizes(dynamicTypeSize: DynamicTypeSize, width: CGFloat) throws {
        let measurements = Measurements()
        let grid = HomeGameCardsGrid(spacing: 20) {
            ForEach(0..<5) { index in
                CardProbe(index: index, measurements: measurements) {
                    Button {} label: {
                        HomeGameCardContent(
                            minimumHeight: AppLayout.cardHeightLarge,
                            identityPosition: index == 0 ? .top : .center
                        ) {
                            Text(index == 1 || index == 4 ? "QUICK\nCROSSWORD" : "ANAGRAM")
                                .font(AppFont.clueLabel(20))
                                .lineLimit(2)
                                .minimumScaleFactor(0.35)
                        } details: {
                            if index == 2 {
                                ProgressView()
                            } else {
                                Text("In Progress")
                                    .font(AppFont.caption())
                            }
                        } accessory: {
                            if index == 0 {
                                // Completed Backword has an extra row below its logo.
                                Color.clear.frame(height: AppLayout.homeCardLetterCellSize)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            CardProbe(index: 5, measurements: measurements) {
                HomeArchiveCard(isProUser: false, openArchive: {})
            }
        }
        .environment(\.horizontalSizeClass, .regular)
        .environment(\.dynamicTypeSize, dynamicTypeSize)

        let size = layout(grid, width: width)
        let tallest = try #require(measurements.idealHeights.values.max())
        #expect(measurements.frames.count == 6)
        #expect(abs(size.height - (3 * tallest + 40)) < 0.5)
        for index in 0..<6 {
            let frame = try #require(measurements.frames[index])
            #expect(abs(frame.width - (width - 20) / 2) < 0.5)
            #expect(abs(frame.height - tallest) < 0.5)
            if index % 2 == 1 {
                let previous = try #require(measurements.frames[index - 1])
                #expect(abs(frame.minY - previous.minY) < 0.5)
                #expect(abs(frame.minX - previous.maxX - 20) < 0.5)
            }
        }
    }

    @Test("Stacked games share a height across the optional compact archive upsell",
          arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility1, .accessibility5],
          [CGFloat(320), 390])
    func stackedCards(dynamicTypeSize: DynamicTypeSize, width: CGFloat) throws {
        for showsUpsell in [false, true] {
            let measurements = Measurements()
            let grid = HomeGameCardsGrid(columns: 1, spacing: 20) {
                ForEach(0..<2) { index in
                    stackedCard(index: index, measurements: measurements)
                }
                Group {
                    if showsUpsell {
                        CardProbe(index: 5, measurements: measurements) {
                            AdFreeExperienceButton(action: {})
                        }
                    }
                }
                .layoutValue(key: HomeGameCardsGridLayout.IntrinsicHeightKey.self, value: true)
                ForEach(2..<5) { index in
                    stackedCard(index: index, measurements: measurements)
                }
            }
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .transaction { $0.disablesAnimations = true }

            let size = layout(grid, width: width)
            let tallest = try #require((0..<5).compactMap { measurements.idealHeights[$0] }.max())
            let upsellHeight = showsUpsell ? try #require(measurements.idealHeights[5]) : 0
            #expect(measurements.frames.count == (showsUpsell ? 6 : 5))
            let totalSpacing: CGFloat = showsUpsell ? 100 : 80
            let expectedHeight = 5 * tallest + upsellHeight + totalSpacing
            #expect(abs(size.height - expectedHeight) < 0.5)
            let order = showsUpsell ? [0, 1, 5, 2, 3, 4] : [0, 1, 2, 3, 4]
            var previousFrame: CGRect?
            for index in order {
                let frame = try #require(measurements.frames[index])
                #expect(abs(frame.width - width) < 0.5)
                #expect(abs(frame.height - (index == 5 ? upsellHeight : tallest)) < 0.5)
                if let previousFrame {
                    #expect(abs(frame.minY - previousFrame.maxY - 20) < 0.5)
                }
                previousFrame = frame
            }
        }
    }

    @Test("New measurements can shrink every row after taller content disappears", arguments: [1, 2])
    func contentCanShrink(columns: Int) {
        for tallest: CGFloat in [194, 400, 194] {
            let grid = HomeGameCardsGrid(columns: columns, spacing: 20) {
                ForEach(0..<6) { index in
                    Color.clear.frame(minHeight: index == 4 ? tallest : 144)
                }
            }
            let rows = CGFloat(6 / columns)
            #expect(layout(grid, width: 580).height == rows * tallest + (rows - 1) * 20)
        }
    }

    private func stackedCard(index: Int, measurements: Measurements) -> some View {
        CardProbe(index: index, measurements: measurements) {
            HomeGameCardContent(minimumHeight: AppLayout.cardHeightSmall) {
                Text(index == 1 || index == 4 ? "QUICK\nCROSSWORD" : "ANAGRAM")
                    .font(AppFont.clueLabel(16))
                    .lineLimit(2)
                    .minimumScaleFactor(0.35)
            } details: {
                if index == 2 {
                    ProgressView()
                } else {
                    Text("In Progress")
                        .font(AppFont.caption())
                }
            } accessory: {
                // Force the tallest content below the upsell to exercise both groups.
                if index == 4 {
                    Color.clear.frame(height: 180)
                }
            }
        }
    }

    @Test("Cards without a grid keep their intrinsic height despite a tall proposal")
    func standaloneCard() {
        let card = HomeGameCardContent(minimumHeight: 144) {
            Color.clear.frame(height: 40)
        } details: {
            Color.clear.frame(height: 28)
        }
        #expect(layout(card, width: 280).height == 144)
    }

    private func layout(_ content: some View, width: CGFloat) -> CGSize {
        #if canImport(UIKit)
        let host = UIHostingController(rootView: content)
        let size = host.sizeThatFits(in: CGSize(width: width, height: 10_000))
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        #else
        let host = NSHostingView(rootView: content.frame(width: width))
        let size = host.fittingSize
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        #endif
        return size
    }

    private final class Measurements {
        var idealHeights: [Int: CGFloat] = [:]
        var frames: [Int: CGRect] = [:]
    }

    /// Records the actual card size, so an outer frame cannot mask a short card.
    private struct CardProbe: Layout {
        let index: Int
        let measurements: Measurements

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let size = subviews[0].sizeThatFits(proposal)
            if proposal.height == nil {
                measurements.idealHeights[index] = size.height
            }
            return size
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let size = subviews[0].sizeThatFits(ProposedViewSize(bounds.size))
            measurements.frames[index] = CGRect(origin: bounds.origin, size: size)
            subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
        }
    }
}
