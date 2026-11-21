import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Home daily challenge layout")
struct HomeDailyChallengeLayoutTests {
    @Test("Profile rows keep titles and statuses readable at narrow widths",
          arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility1, .accessibility5])
    func profileRowAdaptsToTextSize(size: DynamicTypeSize) {
        let progress = DailyChallengeGameProgress(game: .crossword, state: .notStarted)
        let row = ProfileDailyProgressView.gameRow(progress)
            .environment(\.dynamicTypeSize, size)
        let host = UIHostingController(rootView: row)
        let narrow = host.sizeThatFits(in: CGSize(width: 260, height: 1_000))
        let text = Text("Quick Crossword").font(AppFont.body(14))
            .environment(\.dynamicTypeSize, size)
        let lineHeight = UIHostingController(rootView: text)
            .sizeThatFits(in: CGSize(width: 1_000, height: 1_000)).height
        #expect(narrow.width <= 260.5)
        // The two labels may each wrap onto two lines, but must not collapse
        // into the many character-sized lines seen when the status is squeezed.
        #expect(narrow.height <= lineHeight * 5 + AppLayout.profileDailySpacing * 2)
    }

    @Test("Daily progress points use primary text colour")
    func profilePointsColor() {
        #expect(ProfileDailyProgressView.pointsColor == .appTextPrimary)
    }

    @Test("Every progress state uses the same wide rounded rectangular marker",
          arguments: [DailyChallengeGameProgress.State.notStarted, .inProgress,
                      .finished(won: true), .finished(won: false)])
    func rectangularMarker(state: DailyChallengeGameProgress.State) {
        let progress = DailyChallengeGameProgress(game: .crossword, state: state, fillFraction: 0.5)
        let marker = HomeDailyChallengeMarker(progress: progress)
            .environment(\.dynamicTypeSize, .large)
            .environment(\._accessibilityReduceMotion, true)
        let measured = UIHostingController(rootView: marker)
            .sizeThatFits(in: CGSize(width: 280, height: 1_000))

        #expect(measured.width > measured.height)
        #expect(abs(measured.width - AppLayout.homeDailyMarkerWidth) < 0.5)
        #expect(abs(measured.height - AppLayout.homeDailyMarkerHeight) < 0.5)
    }

    @Test("An unfinished crossword marker leaves a visible gap even with one answer left")
    func crosswordMarkerGap() {
        let width = AppLayout.homeDailyMarkerWidth
        let gap = AppLayout.homeDailyMarkerMinimumUnfilledWidth
        let fill = HomeDailyChallengeMarker.partialFillWidth(
            availableWidth: width, fraction: 17.0 / 18.0, minimumUnfilledWidth: gap
        )
        #expect(width - fill >= gap)
        #expect(fill > 0)
        #expect(HomeDailyChallengeMarker.partialFillWidth(
            availableWidth: width, fraction: 1, minimumUnfilledWidth: gap
        ) < width)
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

    @Test("Guide rows keep the celebration score layout throughout the reveal and announce the maximum",
          arguments: DailyChallengeGame.allCases, [DynamicTypeSize.large, .accessibility3])
    func guideRowMeasurements(game: DailyChallengeGame, textSize: DynamicTypeSize) {
        let proposal = CGSize(width: 280, height: 1_000)
        let progress = DailyChallengeFixtures.snapshot(finished: 4)[game]
        let celebration = HomeDailyChallengeCelebrationRow(progress: progress, showsGame: true, showsPoints: true)
            .environment(\.dynamicTypeSize, textSize)
        let celebrationSize = UIHostingController(rootView: celebration).sizeThatFits(in: proposal)

        for phase in HomeDailyChallengeCelebrationRow.GuidePhase.allCases {
            let row = HomeDailyChallengeCelebrationRow(game: game, guidePhase: phase)
            let measured = UIHostingController(rootView: row.environment(\.dynamicTypeSize, textSize))
                .sizeThatFits(in: proposal)
            #expect(measured == celebrationSize)
            #expect(measured.width <= 280.5)
            #expect(row.accessibilityDescription == "\(game.displayName), up to 5 points")
        }
    }

    @Test("The guide fills a double-width capsule and ends on the standard maximum-points score")
    func guideRowArtwork() throws {
        let game = DailyChallengeGame.anagram
        let maximum = DailyChallengeSnapshot.maximumPointsPerGame
        let progress = DailyChallengeGameProgress(game: game, state: .finished(won: true), earnedPoints: maximum)
        let scale: CGFloat = 2
        func render(_ row: HomeDailyChallengeCelebrationRow) throws -> CGImage {
            let renderer = ImageRenderer(content: row
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, .large))
            renderer.proposedSize = ProposedViewSize(width: 280, height: nil)
            renderer.scale = scale
            return try #require(renderer.cgImage)
        }

        let outlineImage = try render(HomeDailyChallengeCelebrationRow(game: game, guidePhase: .marker))
        let filledImage = try render(HomeDailyChallengeCelebrationRow(game: game, guidePhase: .filled))
        try #require(outlineImage.width == filledImage.width && outlineImage.height == filledImage.height)
        let outline = try rgbaPixels(outlineImage)
        let filled = try rgbaPixels(filledImage)
        let changedColumns = Set(outline.indices.compactMap { index in
            outline[index] == filled[index] ? nil : (index / 4) % filledImage.width
        })
        let fillWidth = CGFloat(changedColumns.count) / scale
        #expect(abs(fillWidth - AppLayout.homeDailyMarkerWidth * 2) <= 1)

        let final = try rgbaPixels(render(HomeDailyChallengeCelebrationRow(game: game, guidePhase: .points)))
        let celebration = try rgbaPixels(render(HomeDailyChallengeCelebrationRow(
            progress: progress, showsGame: true, showsPoints: true
        )))
        #expect(filled != final)
        #expect(final == celebration)
    }

    @Test("The rating example fits the points total, track and label in three rows at every tier",
          arguments: [DynamicTypeSize.large, .accessibility3], [0.1, 0.3, 0.6, 0.8, 1.0])
    func guideRatingHeight(textSize: DynamicTypeSize, progress: Double) {
        let proposal = CGSize(width: 280, height: 1_000)
        let example = DailyIntervlsRatingExample(fraction: progress, isPro: false)

        func measure(_ view: some View) -> CGSize {
            UIHostingController(rootView: view.environment(\.dynamicTypeSize, textSize)).sizeThatFits(in: proposal)
        }

        let demo = measure(DailyIntervlsRatingDemoView(progress: progress, isPro: false))
        let total = measure(Text("\(example.points) / \(example.maximumPoints) pts")
            .font(AppFont.statNumber(AppLayout.dailyIntervlsGuidePointsSize))
            .lineLimit(1))
        let tier = measure(RatingBarTierLabel(tier: example.tier))
        let trackStyle = RatingProgressTrack.Style.detailed(markerColor: example.tier.color, pulses: false,
                                                            markerAnimationDelay: 0)
        let expectedHeight = total.height + trackStyle.height + tier.height + AppLayout.homeDailyCelebrationRowSpacing * 2

        #expect(demo.width <= proposal.width)
        #expect(abs(demo.height - expectedHeight) < 1)
    }

    @Test("The text-only celebration fits narrow and short screens in both appearances",
          arguments: [DynamicTypeSize.large, .accessibility3, .accessibility5],
                     [ColorScheme.light, .dark])
    func celebrationViewport(size: DynamicTypeSize, colorScheme: ColorScheme) {
        let card = HomeDailyChallengeCelebration(snapshot: DailyChallengeFixtures.snapshot(finished: 4), dismiss: {}, openArchive: {})
            .environment(\.dynamicTypeSize, size)
            .environment(\.colorScheme, colorScheme)
            .environment(\._accessibilityReduceMotion, true)
        let measured = UIHostingController(rootView: card).sizeThatFits(in: CGSize(width: 320, height: 568))
        #expect(measured.width <= 320.5)
        #expect(measured.height <= 568.5)
    }

    @Test("Both celebration actions fit narrow cards and grow with accessibility text",
          arguments: [DynamicTypeSize.large, .accessibility3, .accessibility5])
    func celebrationActionsFit(size: DynamicTypeSize) {
        let card = HomeDailyChallengeCelebration(
            snapshot: DailyChallengeFixtures.snapshot(finished: 4), dismiss: {}, openArchive: {}
        )
        let actions = card.actions.environment(\.dynamicTypeSize, size)
        let measured = UIHostingController(rootView: actions)
            .sizeThatFits(in: CGSize(width: 220, height: 10_000))
        #expect(measured.width <= 220.5)
        #expect(measured.height >= 2 * AppLayout.minimumTouchTarget
                + AppLayout.homeDailyCelebrationRowSpacing)
        let label = Text("Explore the archive").font(AppFont.clueLabel())
            .environment(\.dynamicTypeSize, size)
        let labelSize = UIHostingController(rootView: label)
            .sizeThatFits(in: CGSize(width: 220, height: 10_000))
        #expect(measured.height >= labelSize.height + 2 * AppLayout.homeDailyCelebrationPadding
                + AppLayout.minimumTouchTarget + AppLayout.homeDailyCelebrationRowSpacing)
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
