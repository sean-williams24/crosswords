import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Game Dynamic Type layout")
struct GameDynamicTypeContainerTests {
    private let puzzle = MidwordPuzzle(
        id: "dynamic-type-test",
        date: "2026-10-07",
        puzzleNumber: 1,
        firstWord: "BANK",
        secondWord: "BOOK",
        answer: "NOTE",
        alternatives: []
    )

    @Test("Standalone keyboard matches Midword's maximum at every accessibility size", arguments: [
        DynamicTypeSize.xxxLarge, .accessibility1, .accessibility2,
        .accessibility3, .accessibility4, .accessibility5
    ], [CGFloat(320), CGFloat(768)])
    func keyboardStaysCompact(size: DynamicTypeSize, width: CGFloat) {
        let keyboard = CustomKeyboardView(onKeyTap: { _ in }, onDelete: {})
        let midwordKeyboard = GameDynamicTypeContainer { keyboard }
        let baseline = fittedKeyboardSize(midwordKeyboard, at: AppLayout.gameMaximumDynamicTypeSize, width: width)
        let enlarged = fittedKeyboardSize(keyboard, at: size, width: width)

        #expect(abs(enlarged.height - baseline.height) < 0.5)
        #expect(enlarged.height < 320)
        #expect(enlarged.width <= width + 0.5)
    }

    @Test("Standalone keyboard continues scaling below Midword's maximum")
    func keyboardPreservesSmallerTextSizes() {
        let keyboard = CustomKeyboardView(onKeyTap: { _ in }, onDelete: {})
        let smaller = fittedKeyboardSize(keyboard, at: .xSmall, width: 320)
        let standard = fittedKeyboardSize(keyboard, at: .large, width: 320)
        let maximum = fittedKeyboardSize(keyboard, at: AppLayout.gameMaximumDynamicTypeSize, width: 320)

        #expect(smaller.height < standard.height)
        #expect(standard.height < maximum.height)
    }

    @Test("Give up flag retains a usable navigation target", arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility5])
    func giveUpFlagHasNavigationTarget(size: DynamicTypeSize) {
        let flag = GiveUpFlagButton(iconSize: 44, glyphSize: 20, action: {})
        let measured = fittedSize(flag, at: size)
        #expect(measured.width >= 44)
        #expect(measured.height >= 44)
    }

    @Test("Prompt words and input cells stop growing at the game text limit", arguments: [
        DynamicTypeSize.xxxLarge, .accessibility1, .accessibility5
    ])
    func boardStaysCompact(size: DynamicTypeSize) {
        let board = MidwordBoardView(puzzle: puzzle, input: "NO", progress: MidwordProgress(date: puzzle.date))
        let baseline = fittedSize(board, at: AppLayout.gameMaximumDynamicTypeSize)
        let enlarged = fittedSize(board, at: size)

        #expect(abs(enlarged.height - baseline.height) < 0.5)
        #expect(enlarged.width <= 320.5)
    }

    @Test("Previous guesses and completion cells keep their bounded heights")
    func letterRowsStayCompact() {
        let rows = VStack(spacing: 0) {
            MidwordGuessRow(guess: "LETTER", isCorrect: false)
            MidwordCompletionWordView(word: "LETTER", failed: false)
        }
        let baseline = fittedSize(rows, at: AppLayout.gameMaximumDynamicTypeSize)
        let enlarged = fittedSize(rows, at: .accessibility5)

        #expect(abs(enlarged.height - baseline.height) < 0.5)
    }

    @Test("Animated guess cells preserve their input and history dimensions", arguments: [
        AppLayout.midwordInputCellSize, AppLayout.midwordGuessCellSize
    ])
    func animatedGuessCellSize(cellSize: CGFloat) {
        let cell = MidwordAnimatedGuessCell(
            letter: "N", size: cellSize, guessIndex: 0, letterIndex: 0, namespace: nil
        )
        let measured = fittedSize(cell, at: .large)

        #expect(abs(measured.width - cellSize) < 0.5)
        #expect(abs(measured.height - cellSize) < 0.5)
    }

    @Test("Fading scroll content keeps a bounded viewport and space to reveal the final guess", arguments: [1, 20])
    func fadingScrollKeepsHistoryReachable(count: Int) throws {
        let fadeHeight = AppLayout.midwordScrollFadeHeight
        let rowHeight = AppLayout.midwordGuessCellSize
        let host = UIHostingController(rootView:
            BottomFadingScrollView(fadeHeight: fadeHeight) {
                VStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { index in
                        Text("Guess \(index)").frame(height: rowHeight)
                    }
                }
            }
        )
        try withLaidOutHostingController(host, size: CGSize(width: 320, height: 200)) {
            func findScrollView(in view: UIView) -> UIScrollView? {
                if let scroll = view as? UIScrollView { return scroll }
                return view.subviews.lazy.compactMap { findScrollView(in: $0) }.first
            }
            let scroll = try #require(findScrollView(in: host.view))
            #expect(scroll.bounds.height <= 200.5)
            #expect(scroll.contentSize.height >= CGFloat(count) * rowHeight + fadeHeight - 0.5)
            if count > 1 { #expect(scroll.contentSize.height > scroll.bounds.height) }
        }
    }

    @Test("Custom fonts stop growing while smaller text settings are preserved")
    func typographyUsesBoundedEnvironment() {
        let text = Text("Find the link that ends the top word and starts the bottom word to make 2 new words")
            .font(AppFont.body())
            .multilineTextAlignment(.center)
        let baseline = fittedSize(text, at: AppLayout.gameMaximumDynamicTypeSize)
        let enlarged = fittedSize(text, at: .accessibility5)
        let smaller = fittedSize(text, at: .xSmall)

        #expect(abs(enlarged.height - baseline.height) < 0.5)
        #expect(smaller.height < baseline.height)
    }

    private func fittedKeyboardSize<Content: View>(_ content: Content, at size: DynamicTypeSize, width: CGFloat) -> CGSize {
        let host = UIHostingController(rootView:
            content
                .environment(\.dynamicTypeSize, size)
                // Use SwiftUI's writable test override for the read-only system value.
                .environment(\._accessibilityReduceMotion, true)
        )
        return host.sizeThatFits(in: CGSize(width: width, height: 10_000))
    }

    private func fittedSize<Content: View>(_ content: Content, at size: DynamicTypeSize) -> CGSize {
        let host = UIHostingController(rootView:
            GameDynamicTypeContainer { content }
                .environment(\.dynamicTypeSize, size)
                .environment(\._accessibilityReduceMotion, true)
        )
        return host.sizeThatFits(in: CGSize(width: 320, height: 10_000))
    }
}
