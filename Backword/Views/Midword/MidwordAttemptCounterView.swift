import SwiftUI

struct MidwordAttemptCounterView: View {
    let progress: MidwordProgress

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                let isUsed = index < progress.guesses.count
                let isWinSlot = progress.isWon && index == progress.guesses.count - 1
                RoundedRectangle(cornerRadius: 3)
                    .fill(progress.isFailed ? Color.appGaveUp :
                        isWinSlot ? Color.midwordAccent :
                        isUsed ? Color.midwordAccent.opacity(0.7) : Color.midwordBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(
                                isWinSlot ? Color.midwordAccent :
                                    isUsed ? Color.midwordAccent.opacity(0.5) : Color.midwordInactiveCellBorder,
                                lineWidth: 1
                            )
                    }
                    .frame(width: 36, height: 10)
                    .animation(.easeInOut(duration: 0.25), value: progress.guesses.count)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(max(0, 5 - progress.guesses.count)) attempts remaining")
    }
}
