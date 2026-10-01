import SwiftUI

struct MidwordCompletionWordView: View {
    let word: String
    let failed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric private var cellSize: CGFloat = 44
    @State private var revealStep = 0
    @State private var celebrates = false
    private let haptics = HapticsEngine()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(word.enumerated()), id: \.offset) { index, letter in
                    let revealed = BackwordCompletionAnimation.revealedIndices(
                        letterCount: word.count, revealStep: revealStep
                    ).contains(index)
                    BackwordLetterCell(
                        letter: revealed ? letter : nil,
                        isCorrect: revealed && !failed,
                        isFailed: revealed && failed,
                        isCelebrating: revealed && celebrates && !failed,
                        size: cellSize,
                        cornerRadius: 0,
                        accentColor: .midwordAccent,
                        surfaceColor: .midwordBackground,
                        textColor: .appTextPrimary,
                        correctColor: .midwordAccent
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scaleEffect(celebrates ? 1.06 : 1)
        .task(id: word) { await animate() }
    }

    @MainActor
    private func animate() async {
        revealStep = reduceMotion ? word.count : 0
        celebrates = false
        guard !reduceMotion else { return }
        for step in BackwordCompletionAnimation.revealSteps(letterCount: word.count) {
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) { revealStep = step }
            haptics.play(.backwordCompletionLetterRevealed)
        }
        guard !failed else { return }
        try? await Task.sleep(for: .milliseconds(320))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.48)) { celebrates = true }
        try? await Task.sleep(for: .milliseconds(280))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { celebrates = false }
    }
}
