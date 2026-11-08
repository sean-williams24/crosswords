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
            .environment(\.accessibilityReduceMotion, true)
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
            .environment(\.accessibilityReduceMotion, true)
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
}
