import SwiftUI

struct BackwordCompletionWordView: View {
    let word: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var revealStep = 0
    @State private var celebrates = false

    private var letters: [Character] {
        Array(word.uppercased())
    }

    private var cellSize: CGFloat {
        horizontalSizeClass == .regular ? 60 : 44
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                let isRevealed = BackwordCompletionAnimation.revealedIndices(
                    letterCount: letters.count,
                    revealStep: revealStep
                ).contains(index)

                BackwordLetterCell(
                    letter: isRevealed ? letter : nil,
                    isCorrect: isRevealed,
                    isCelebrating: isRevealed && celebrates,
                    size: cellSize
                )
            }
        }
        .scaleEffect(celebrates ? 1.08 : 1)
        .offset(y: celebrates ? -6 : 0)
        .shadow(
            color: Color.appAccent.opacity(celebrates ? 0.45 : 0),
            radius: celebrates ? 14 : 0
        )
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .task(id: word) {
            await animateCompletion()
        }
    }

    @MainActor
    private func animateCompletion() async {
        revealStep = reduceMotion ? letters.count : 0
        celebrates = false
        guard !reduceMotion else { return }

        for step in 1...letters.count {
            guard await pause(nanoseconds: 140_000_000) else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                revealStep = step
            }
        }

        guard await pause(nanoseconds: 320_000_000) else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.48)) {
            celebrates = true
        }

        guard await pause(nanoseconds: 280_000_000) else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
            celebrates = false
        }
    }

    private func pause(nanoseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

#Preview {
    BackwordCompletionWordView(word: "CASTLE")
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
