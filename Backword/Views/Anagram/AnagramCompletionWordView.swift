import SwiftUI

struct AnagramCompletionWordView: View {
    let word: String
    let celebrates: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealStep = 0
    @State private var isCelebrating = false

    private var letters: [Character] {
        Array(word.uppercased())
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: AppLayout.anagramAnswerTileSpacing),
            count: letters.count
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: AppLayout.anagramAnswerTileSpacing) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                let isRevealed = AnagramCompletionAnimation.revealedIndices(
                    letterCount: letters.count,
                    revealStep: revealStep
                ).contains(index)

                ZStack {
                    Rectangle()
                        .fill(isRevealed ? Color.anagramOrange : Color.anagramSurface)
                    Rectangle()
                        .strokeBorder(Color.anagramOrange, lineWidth: 1)
                    if isRevealed {
                        Text(String(letter))
                            .font(AppFont.header(24))
                            .foregroundStyle(Color.anagramOnOrange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .transition(.scale(scale: 0.45).combined(with: .opacity))
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .scaleEffect(isRevealed ? 1 : 0.84)
                .opacity(isRevealed ? 1 : 0.7)
            }
        }
        .scaleEffect(isCelebrating ? 1.04 : 1)
        .offset(y: isCelebrating ? -5 : 0)
        .shadow(
            color: Color.anagramOrange.opacity(isCelebrating ? 0.4 : 0),
            radius: isCelebrating ? 14 : 0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .task(id: word) {
            await animateCompletion()
        }
    }

    @MainActor
    private func animateCompletion() async {
        revealStep = reduceMotion ? letters.count : 0
        isCelebrating = false
        guard !reduceMotion else { return }

        for step in AnagramCompletionAnimation.revealSteps(letterCount: letters.count) {
            guard await pause(seconds: AnagramCompletionAnimation.revealInterval) else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.68)) {
                revealStep = step
            }
        }

        guard celebrates, await pause(seconds: 0.28) else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.5)) {
            isCelebrating = true
        }
        guard await pause(seconds: 0.28) else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.64)) {
            isCelebrating = false
        }
    }

    private func pause(seconds: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

#Preview {
    AnagramCompletionWordView(word: "TRIANGLE", celebrates: true)
        .padding(AppLayout.screenPadding)
        .background(Color.appBackground)
}
