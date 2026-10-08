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

    @Test("Keyboard stays compact above the game text limit", arguments: [
        DynamicTypeSize.xxxLarge, .accessibility1, .accessibility5
    ])
    func keyboardStaysCompact(size: DynamicTypeSize) {
        let keyboard = CustomKeyboardView(onKeyTap: { _ in }, onDelete: {})
        let baseline = fittedSize(keyboard, at: AppLayout.gameMaximumDynamicTypeSize)
        let enlarged = fittedSize(keyboard, at: size)

        #expect(abs(enlarged.height - baseline.height) < 0.5)
        #expect(enlarged.height < 320)
        #expect(enlarged.width <= 320.5)
    }

    @Test("Prompt words and input cells stop growing at the game text limit", arguments: [
        DynamicTypeSize.xxxLarge, .accessibility1, .accessibility5
    ])
    func boardStaysCompact(size: DynamicTypeSize) {
        let board = MidwordBoardView(puzzle: puzzle, input: "NO", won: false)
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

    private func fittedSize<Content: View>(_ content: Content, at size: DynamicTypeSize) -> CGSize {
        let host = UIHostingController(rootView:
            GameDynamicTypeContainer { content }
                .environment(\.dynamicTypeSize, size)
                .environment(\.accessibilityReduceMotion, true)
        )
        return host.sizeThatFits(in: CGSize(width: 320, height: 10_000))
    }
}
