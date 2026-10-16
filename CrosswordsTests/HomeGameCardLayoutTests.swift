import CoreGraphics
import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import Backword

@Suite("Home card identity alignment")
struct HomeGameCardLayoutTests {
    @Test("The final Home card has the same gap above the tab bar as between cards")
    func bottomScrollSpacing() {
        #expect(HomeGamesLayout.spacing == 20)
        #expect(HomeGamesLayout.scrollBottomPadding >= 0)
        #expect(HomeGamesLayout.scrollBottomPadding + AppLayout.homeTabBarTopPadding
                == HomeGamesLayout.spacing)
    }

    @Test("Normal game titles stay centred while header badges and footer keep the compact height",
          arguments: [CGFloat(180), 280, 600])
    func compactGameStates(width: CGFloat) {
        let states: [(identity: CGFloat, header: CGFloat, details: CGFloat, spacing: CGFloat)] = [
            (30, 0, 28, 8), // Anagram before completion.
            (AppLayout.midwordHomeCardLogoHeight, 32, 32, 8),
            (AppLayout.homeCardLogoHeight, 32, 32, 4),
            (38, 32, 32, 8) // Crossword title and footer.
        ]
        for heights in states {
            for minimumHeight: CGFloat in [120, 170] {
                let frames = HomeGameCardLayout.frames(
                    width: width, minimumHeight: minimumHeight,
                    heights: [.identity: heights.identity, .header: heights.header, .details: heights.details],
                    spacing: heights.spacing
                )
                #expect(frames.size.height == minimumHeight)
                #expect(frames.identity.midY == frames.size.height / 2)
                #expect(frames.identity.midX == width / 2)
                #expect(frames.details.maxY == minimumHeight)
                #expect(frames.identity.maxY + heights.spacing <= frames.details.minY)
                if heights.header > 0 {
                    #expect(frames.header.maxY + heights.spacing <= frames.identity.minY)
                }
            }
        }
    }

    @Test("Completed Backword keeps the compact logo, cells, and footer arrangement")
    func completedBackword() {
        let frames = HomeGameCardLayout.frames(
            width: 280, minimumHeight: 120,
            heights: [.header: 32, .identity: AppLayout.homeCardLogoHeight, .accessory: AppLayout.homeCardLetterCellSize, .details: 32],
            spacing: 4, identityPosition: .top
        )
        #expect(frames.size.height == 120)
        #expect(frames.identity.minY == 0)
        #expect(frames.header.minY == 0)
        #expect(frames.accessory.minY == AppLayout.homeCardLogoHeight + 4)
        #expect(frames.details.maxY == 120)
        #expect(frames.accessory.maxY + 4 <= frames.details.minY)
    }

    @MainActor
    @Test("Hosted branding stays at the card centre independently of top and bottom badges")
    func hostedCenteredBrand() {
        #if canImport(UIKit)
        let brandView = UIView()
        let headerView = UIView()
        #else
        let brandView = NSView()
        let headerView = NSView()
        #endif
        let card = HomeGameCardContent(minimumHeight: 144) {
            CardRegionMarker(view: brandView).frame(width: 140, height: 38)
        } details: {
            Color.clear.frame(height: 32)
        } header: {
            HomeGameCardHeader(spacing: 8) {
                CardRegionMarker(view: headerView).frame(width: 40, height: 16)
            } streak: {
                Color.clear.frame(width: 52, height: 32)
            }
        }
        .frame(width: 280)
        #if canImport(UIKit)
        let host = UIHostingController(rootView: card)
        let size = host.sizeThatFits(in: CGSize(width: 280, height: 10_000))
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        let brandFrame = brandView.convert(brandView.bounds, to: host.view)
        let headerFrame = headerView.convert(headerView.bounds, to: host.view)
        let topDistance = headerFrame.minY
        #else
        let host = NSHostingView(rootView: card)
        let size = host.fittingSize
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        let brandFrame = brandView.convert(brandView.bounds, to: host)
        let headerFrame = headerView.convert(headerView.bounds, to: host)
        let topDistance = host.isFlipped ? headerFrame.minY : size.height - headerFrame.maxY
        #endif
        #expect(size.height == 144)
        #expect(abs(brandFrame.midX - size.width / 2) < 0.5)
        #expect(abs(brandFrame.midY - size.height / 2) < 0.5)
        #expect(abs(headerFrame.midX - size.width / 2) < 0.5)
        #expect(abs(topDistance - 12) < 0.5)
    }

    @MainActor
    @Test("Crossword title and dimensions centre together without increasing the compact height")
    func combinedCrosswordIdentity() {
        #if canImport(UIKit)
        let titleView = UIView()
        let dimensionsView = UIView()
        #else
        let titleView = NSView()
        let dimensionsView = NSView()
        #endif
        let card = HomeGameCardContent(minimumHeight: 144, spacing: .zero) {
            VStack(spacing: 4) {
                CardRegionMarker(view: titleView).frame(width: 140, height: 38)
                CardRegionMarker(view: dimensionsView).frame(width: 40, height: 16)
            }
        } details: {
            Color.clear.frame(height: 28)
        } header: {
            HomeGameCardHeader(spacing: 8) {
                EmptyView()
            } streak: {
                Color.clear.frame(width: 52, height: 28)
            }
        }
        .frame(width: 280)
        #if canImport(UIKit)
        let host = UIHostingController(rootView: card)
        let size = host.sizeThatFits(in: CGSize(width: 280, height: 10_000))
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        let titleFrame = titleView.convert(titleView.bounds, to: host.view)
        let dimensionsFrame = dimensionsView.convert(dimensionsView.bounds, to: host.view)
        let gap = dimensionsFrame.minY - titleFrame.maxY
        #else
        let host = NSHostingView(rootView: card)
        let size = host.fittingSize
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        let titleFrame = titleView.convert(titleView.bounds, to: host)
        let dimensionsFrame = dimensionsView.convert(dimensionsView.bounds, to: host)
        let gap = host.isFlipped
            ? dimensionsFrame.minY - titleFrame.maxY
            : titleFrame.minY - dimensionsFrame.maxY
        #endif
        let combinedFrame = titleFrame.union(dimensionsFrame)
        #expect(size.height == 144)
        #expect(abs(gap - 4) < 0.5)
        #expect(abs(combinedFrame.midY - size.height / 2) < 0.5)
        #expect(abs(titleFrame.midX - size.width / 2) < 0.5)
        #expect(abs(dimensionsFrame.midX - size.width / 2) < 0.5)
    }

    @Test("Accessibility text can grow the card without overlapping its footer")
    func enlargedText() {
        let frames = HomeGameCardLayout.frames(
            width: 280, minimumHeight: 120,
            heights: [.header: 120, .identity: 200, .accessory: 180, .details: 180], spacing: 8
        )
        #expect(frames.header.maxY + 8 <= frames.identity.minY)
        #expect((frames.identity.minY + frames.accessory.maxY) / 2 == frames.size.height / 2)
        #expect(frames.accessory.minY == frames.identity.maxY + 8)
        #expect(frames.accessory.maxY + 8 <= frames.details.minY)
        #expect(frames.size.height > 120)
    }

    @MainActor
    @Test("Shared card content keeps plain logos, crossword groups, and completed games compact")
    func sharedContent() {
        let plain = HomeGameCardContent(minimumHeight: 144) {
            Color.clear.frame(height: AppLayout.midwordHomeCardLogoHeight)
        } details: {
            Color.clear.frame(height: 28)
        }
        let described = HomeGameCardContent(minimumHeight: 144, spacing: .zero) {
            VStack(spacing: 4) {
                Color.clear.frame(height: 38)
                Color.clear.frame(height: 16)
            }
        } details: {
            Color.clear.frame(height: 28)
        } header: {
            Color.clear.frame(height: 28)
        }
        let completed = HomeGameCardContent(minimumHeight: 144, identityPosition: .top, spacing: 4) {
            Color.clear.frame(height: AppLayout.homeCardLogoHeight)
        } details: {
            Color.clear.frame(height: 32)
        } accessory: {
            Color.clear.frame(height: 32)
        } header: {
            HomeGameCardHeader(spacing: 8) {
                EmptyView()
            } streak: {
                Color.clear.frame(width: 52, height: 32)
            }
        }
        for card in [AnyView(plain), AnyView(described), AnyView(completed)] {
            #if canImport(UIKit)
            let host = UIHostingController(rootView: card)
            let size = host.sizeThatFits(in: CGSize(width: 280, height: 10_000))
            #else
            let host = NSHostingView(rootView: card.frame(width: 280))
            let size = host.fittingSize
            #endif
            #expect(size.width == 280)
            #expect(size.height == 144)
        }
    }

    @Test("Omitted SwiftUI regions do not shift the title or require array slots")
    func omittedRegions() {
        let cases: [[HomeGameCardLayout.Region: CGFloat]] = [
            [:],
            [.identity: 30],
            [.identity: 30, .details: 48],
            [.identity: 64, .accessory: 20],
            [.details: 48]
        ]
        for heights in cases {
            let frames = HomeGameCardLayout.frames(
                width: 280, minimumHeight: 120, heights: heights, spacing: 8
            )

            #expect((frames.identity.minY + frames.accessory.maxY) / 2 == frames.size.height / 2)
            #expect(frames.details.height == heights[.details, default: 0])
            #expect(frames[.identity] == frames.identity)
            #expect(frames.size.height >= 120)
        }
    }

    @MainActor
    @Test("SwiftUI can measure cards with a missing footer",
          arguments: [false, true])
    func measuresConditionalSubviews(showDetails: Bool) {
        let card = HomeGameCardLayout(minimumHeight: 120, spacing: 8) {
            Color.clear.frame(width: 280, height: 30)
                .layoutValue(key: HomeGameCardLayout.RegionKey.self, value: .identity)
            if showDetails {
                Color.clear.frame(width: 280, height: 28)
                    .layoutValue(key: HomeGameCardLayout.RegionKey.self, value: .details)
            }
        }

        #if canImport(UIKit)
        let host = UIHostingController(rootView: card)
        let size = host.sizeThatFits(in: CGSize(width: 280, height: 10_000))
        #else
        let host = NSHostingView(rootView: card)
        let size = host.fittingSize
        #endif

        #expect(size.width == 280)
        #expect(size.height == 120)
    }
}

#if canImport(UIKit)
private struct CardRegionMarker: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
#else
private struct CardRegionMarker: NSViewRepresentable {
    let view: NSView
    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
