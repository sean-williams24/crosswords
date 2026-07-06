import SwiftUI

struct DailyCrosswordInstructionsContentView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ScaledMetric private var iconFrame: CGFloat = 22

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    instructionRow(number: "1", text: "Complete the grid and lock-in your score before the next crossword refreshes at midnight")
                    instructionRow(number: "2", text: "Tap a cell to select it, tap the same cell again to switch direction, or use the clue list to browse all clues")
                    instructionRow(number: "3", text: "Tap Get hint to reveal an alternate clue. Free users watch an ad for a hint; Pro users get hints without ads")
                    instructionRow(number: "4", text: "Pro users are able to give up and reveal the answers")
                }

                Divider()
                    .background(Color.appGridLine)

                answerFeedbackToggle

                Divider()
                    .background(Color.appGridLine)

                scoringSection
            }
            .padding(20)
        }
        .background(Color.appBackground)
    }

    private var answerFeedbackToggle: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.appCorrect)
                    .frame(width: iconFrame, height: iconFrame)

                Text("Answer Feedback")
                    .font(AppFont.clueLabel(15))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Spacer()

                Toggle("", isOn: $settings.crosswordCorrectHighlight)
                    .labelsHidden()
                    .tint(.appAccent)
            }

            Text("When enabled, correctly completed answers are highlighted green and locked. Turn it off for a harder experience with no feedback.")
                .font(AppFont.body(14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "star.circle")
                    .foregroundColor(.appAccent)
                    .frame(width: iconFrame, height: iconFrame)

                Text("Scoring")
                    .font(AppFont.clueLabel(15))
                    .foregroundColor(.appTextPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                scoringRow(label: "100% complete", points: "5 pts")
                scoringRow(label: "75-99% complete", points: "4 pts")
                scoringRow(label: "50-74% complete", points: "3 pts")
                scoringRow(label: "25-49% complete", points: "2 pts")
                scoringRow(label: "1-24% complete", points: "1 pt")
                scoringRow(label: "0% complete", points: "0 pts")
            }

            Text("Every 3 hints deducts 1 point from your score, down to 0.")
                .font(AppFont.body(14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(AppFont.clueLabel(13))
                .foregroundColor(.white)
                .frame(width: iconFrame, height: iconFrame)
                .background(Color.appAccent)
                .clipShape(Circle())

            Text(text)
                .font(AppFont.body(14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func scoringRow(label: String, points: String) -> some View {
        HStack {
            Text(label)
                .font(AppFont.body(14))
                .foregroundColor(.appTextSecondary)

            Spacer()

            Text(points)
                .font(AppFont.clueLabel(14))
                .foregroundColor(.appAccent)
        }
    }
}

#Preview {
    DailyCrosswordInstructionsContentView()
}
