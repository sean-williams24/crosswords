import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Home daily challenge layout")
struct HomeDailyChallengeLayoutTests {
    @Test("Every progress state uses the same wide rounded rectangular marker",
          arguments: [DailyChallengeGameProgress.State.notStarted, .inProgress,
                      .finished(won: true), .finished(won: false)])
    func rectangularMarker(state: DailyChallengeGameProgress.State) {
        let progress = DailyChallengeGameProgress(game: .crossword, state: state, crosswordFraction: 0.5)
        let marker = HomeDailyChallengeMarker(progress: progress)
            .environment(\.dynamicTypeSize, .large)
            .environment(\._accessibilityReduceMotion, true)
        let measured = UIHostingController(rootView: marker)
            .sizeThatFits(in: CGSize(width: 280, height: 1_000))

        #expect(measured.width > measured.height)
        #expect(abs(measured.width - AppLayout.homeDailyMarkerWidth) < 0.5)
        #expect(abs(measured.height - AppLayout.homeDailyMarkerHeight) < 0.5)
    }

    @Test("Default text shares one existing label row")
    func compactRow() {
        let host = UIHostingController(rootView: row(tier: "NOVICE", size: .large))
        let measured = host.sizeThatFits(in: CGSize(width: 350, height: 1_000))
        #expect(measured.width <= 350)
        #expect(measured.height <= 20.5)
    }

    @Test("A long tier falls back to multiple lines rather than colliding with the summary")
    func longTierWraps() {
        let host = UIHostingController(rootView: row(tier: "GRANDMASTER WORDSMITH", size: .large))
        let measured = host.sizeThatFits(in: CGSize(width: 220, height: 1_000))
        #expect(measured.width <= 220.5)
        #expect(measured.height > 20)
    }

    @Test("Long tier names and accessibility text fit narrow widths",
          arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility1, .accessibility5])
    func wrapping(size: DynamicTypeSize) {
        let width: CGFloat = 280
        let host = UIHostingController(rootView: row(tier: "GRANDMASTER", size: size))
        let measured = host.sizeThatFits(in: CGSize(width: width, height: 1_000))
        #expect(measured.width <= width + 0.5)
        #expect(measured.height >= 20)
        if size.isAccessibilitySize { #expect(measured.height > 20) }
    }

    @Test("Completion outlines leave both natural and shared card dimensions unchanged",
          arguments: [false, true])
    func cardMeasurements(sharedHeight: Bool) {
        let entry = DailyChallengeFixtures.snapshot(finished: 4)[.backword]
        let card = HomeGameCardContent(minimumHeight: AppLayout.cardHeightSmall) {
            Text("BACKWORD").font(AppFont.header(24))
        } details: {
            Text("3 guesses").font(AppFont.caption())
        }
        .environment(\.homeCardFillsProposedHeight, sharedHeight)
        let proposal = CGSize(width: 280, height: sharedHeight ? 220 : 1_000)
        let original = UIHostingController(rootView: card).sizeThatFits(in: proposal)
        let highlighted = UIHostingController(rootView: card.modifier(HomeDailyChallengeCardHighlight(progress: entry)))
            .sizeThatFits(in: proposal)
        #expect(original == highlighted)
    }

    @Test("The finished summary fits in either appearance with reduced motion",
          arguments: [ColorScheme.light, .dark])
    func reducedMotion(colorScheme: ColorScheme) {
        let summary = HomeDailyChallengeSummary(snapshot: DailyChallengeFixtures.snapshot(finished: 4), celebrationID: 1)
            .environment(\.colorScheme, colorScheme)
            .environment(\._accessibilityReduceMotion, true)
        let measured = UIHostingController(rootView: summary).sizeThatFits(in: CGSize(width: 280, height: 1_000))
        #expect(measured.width <= 280)
        #expect(measured.height > 0)
    }

    private func row(tier: String, size: DynamicTypeSize) -> some View {
        HomeDailyChallengeRatingRow(snapshot: DailyChallengeFixtures.snapshot(finished: 2)) {
            Text(tier).font(AppFont.clueLabel(10)).tracking(1.5)
        }
        .frame(minHeight: 20)
        .environment(\.dynamicTypeSize, size)
    }

    @Test("Celebration rows reserve the same space before and after revealing scores",
          arguments: DailyChallengeGame.allCases)
    func celebrationRowMeasurements(game: DailyChallengeGame) {
        let progress = DailyChallengeFixtures.snapshot(finished: 4)[game]
        let hidden = HomeDailyChallengeCelebrationRow(progress: progress, showsGame: false, showsPoints: false)
        let visible = HomeDailyChallengeCelebrationRow(progress: progress, showsGame: true, showsPoints: true)
        let proposal = CGSize(width: 280, height: 1_000)
        let initial = UIHostingController(rootView: hidden).sizeThatFits(in: proposal)
        let final = UIHostingController(rootView: visible).sizeThatFits(in: proposal)
        #expect(initial == final)
        #expect(final.width <= 280.5)
    }

    @Test("The celebration fits narrow and short screens with accessibility text",
          arguments: [DynamicTypeSize.large, .accessibility5])
    func celebrationViewport(size: DynamicTypeSize) {
        let card = HomeDailyChallengeCelebration(snapshot: DailyChallengeFixtures.snapshot(finished: 4), dismiss: {})
            .environment(\.dynamicTypeSize, size)
            .environment(\._accessibilityReduceMotion, true)
        let measured = UIHostingController(rootView: card).sizeThatFits(in: CGSize(width: 320, height: 568))
        #expect(measured.width <= 320.5)
        #expect(measured.height <= 568.5)
    }

    @Test("Celebration text titles render as one line at narrow widths and every text size",
          arguments: DynamicTypeSize.allCases, [CGFloat(120), CGFloat(204)])
    func celebrationTitlesStayOnOneLine(size: DynamicTypeSize, width: CGFloat) throws {
        for game in [DailyChallengeGame.crossword, .anagram] {
            let title = HomeDailyChallengeCelebrationLogo(game: game)
                .environment(\.dynamicTypeSize, size)
            let renderer = ImageRenderer(content: title)
            renderer.proposedSize = ProposedViewSize(width: width, height: nil)
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            let pixels = try rgbaPixels(image)
            var lines = 0
            var previousRowHasInk = false
            for y in 0..<image.height {
                let rowHasInk = (0..<image.width).contains { x in
                    pixels[(y * image.width + x) * 4 + 3] > 0
                }
                if rowHasInk && !previousRowHasInk { lines += 1 }
                previousRowHasInk = rowHasInk
            }
            #expect(lines == 1, "\(game.displayName) must render as a single line")
            #expect(CGFloat(image.width) / renderer.scale <= width + 0.5)
        }
    }

    @Test("Backword and Midword reserve matching logo heights in both themes",
          arguments: DynamicTypeSize.allCases)
    func celebrationLogoArtwork(size: DynamicTypeSize) throws {
        for scheme in [ColorScheme.light, .dark] {
            var heights: [CGFloat] = []
            for game in [DailyChallengeGame.backword, .midword] {
                let logo = HomeDailyChallengeCelebrationLogo(game: game)
                    .environment(\.colorScheme, scheme)
                    .environment(\.dynamicTypeSize, size)
                let renderer = ImageRenderer(content: logo)
                renderer.scale = 2
                let image = try #require(renderer.cgImage)
                heights.append(CGFloat(image.height) / renderer.scale)
                #expect(!(try artworkBounds(image)).isNull)
            }
            #expect(abs(heights[0] - heights[1]) <= 1)
        }
    }

    @Test("Midword retains all source artwork across Dynamic Type and display scales",
          arguments: DynamicTypeSize.allCases, [CGFloat(2), CGFloat(3)])
    func midwordArtworkDoesNotClip(size: DynamicTypeSize, displayScale: CGFloat) throws {
        for scheme in [ColorScheme.light, .dark] {
            let logo = HomeDailyChallengeCelebrationLogo(game: .midword)
                .environment(\.colorScheme, scheme)
                .environment(\.dynamicTypeSize, size)
                .environment(\.displayScale, displayScale)
            let measured = UIHostingController(rootView: logo)
                .sizeThatFits(in: CGSize(width: 1_000, height: 1_000))
            let bounds = AppLayout.homeDailyCelebrationMidwordArtworkBounds
            let canvas = AppLayout.homeDailyCelebrationMidwordCanvasSize
            // Compare ink coverage with the complete, uncropped asset at the
            // same scale. Padding captures any artwork outside the layout frame.
            let reference = Image("MidwordLogo")
                .resizable()
                .frame(width: measured.width * canvas.width / bounds.width,
                       height: measured.height * canvas.height / bounds.height)
                .environment(\.displayScale, displayScale)
            let originalRenderer = ImageRenderer(content: reference.padding(AppLayout.homeDailyCelebrationPadding))
            let logoRenderer = ImageRenderer(content: logo.padding(AppLayout.homeDailyCelebrationPadding))
            originalRenderer.scale = displayScale
            logoRenderer.scale = displayScale
            let original = try #require(originalRenderer.cgImage)
            let rendered = try #require(logoRenderer.cgImage)
            let originalInk = try alphaCoverage(original)
            let renderedInk = try alphaCoverage(rendered)
            #expect(originalInk > 0)
            // Allow subpixel resampling, but not cropped letters.
            #expect(abs(renderedInk - originalInk) / originalInk < 0.0025)
        }
    }

    private func rgbaPixels(_ image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        }
        return pixels
    }

    private func alphaCoverage(_ image: CGImage) throws -> Double {
        let pixels = try rgbaPixels(image)
        return stride(from: 3, to: pixels.count, by: 4).reduce(0) { $0 + Double(pixels[$1]) }
    }

    private func artworkBounds(_ image: CGImage) throws -> CGRect {
        let width = image.width
        let height = image.height
        let pixels = try rgbaPixels(image)
        var bounds = CGRect.null
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 0 {
                bounds = bounds.union(CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1))
            }
        }
        #expect(!bounds.isNull)
        return bounds
    }
}
