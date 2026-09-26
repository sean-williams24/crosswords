import SwiftUI

struct AnagramInstructionsContentView: View {
    struct ScoringRule: Identifiable, Equatable {
        let label: String
        let points: String

        var id: String { label }
    }

    @ScaledMetric private var iconFrame: CGFloat = 22

    static let scoringRules = [
        ScoringRule(label: "Under 30 seconds", points: "5 pts"),
        ScoringRule(label: "30–59 seconds", points: "4 pts"),
        ScoringRule(label: "1:00–1:59", points: "3 pts"),
        ScoringRule(label: "2:00–2:59", points: "2 pts"),
        ScoringRule(label: "3:00 or longer", points: "1 pt"),
        ScoringRule(label: "Give up", points: "0 pts")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                gameplaySection

                Divider()
                    .overlay(Color.anagramOrange.opacity(0.25))

                timerSection

                Divider()
                    .overlay(Color.anagramOrange.opacity(0.25))

                hintSection

                Divider()
                    .overlay(Color.anagramOrange.opacity(0.25))

                scoringSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground)
    }

    private var gameplaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "hand.tap", title: "Gameplay")

            instructionRow(
                icon: "textformat.abc",
                text: "Tap the scrambled letters in order to build the answer from left to right. Every tile is used once."
            )
            instructionRow(
                icon: "arrow.uturn.backward",
                text: "Undo removes your last letter. Shuffle changes the tray order without changing your answer."
            )
            instructionRow(
                icon: "arrow.counterclockwise",
                text: "Restart returns your placed letters to the tray. Your timer and any used hint are preserved."
            )
            instructionRow(
                icon: "flag.fill",
                text: "Give up reveals the answer, ends the attempt, and awards zero points."
            )
        }
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "timer", title: "Timer")

            Text("The timer starts when you tap Start and measures real elapsed time. It continues while the app is in the background or you leave the game, and stops when you solve or give up. There is no time limit.")
                .font(AppFont.body(14))
                .foregroundStyle(Color.anagramInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hintSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "lightbulb", title: "Hint")

            Text("You can reveal one letter per game. Using a hint returns your placed letters to the tray, then locks one correct letter in the answer so it cannot be undone.")
                .font(AppFont.body(14))
                .foregroundStyle(Color.anagramInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("Free players can watch a rewarded ad. If an ad is unavailable, or if you are a Pro player, the hint adds 30 seconds to your scoring time.")
                .font(AppFont.body(14))
                .foregroundStyle(Color.anagramInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "star.circle", title: "Scoring")

            ForEach(Self.scoringRules) { rule in
                HStack {
                    Text(rule.label)
                        .font(AppFont.body(14))
                        .foregroundStyle(Color.anagramInk)

                    Spacer()

                    Text(rule.points)
                        .font(AppFont.clueLabel(14))
                        .foregroundStyle(Color.anagramOrange)
                }
            }

            Text("Your score uses your elapsed time plus any 30-second hint penalty. Only a solve completed on the puzzle's release day adds points to your rolling 14-day rating and streak.")
                .font(AppFont.body(14))
                .foregroundStyle(Color.anagramInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionTitle(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(AppFont.clueLabel(14))
                .foregroundStyle(Color.anagramOrange)
                .frame(width: iconFrame, height: iconFrame)

            Text(title)
                .font(AppFont.clueLabel(15))
                .foregroundStyle(Color.anagramInk)
        }
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(AppFont.clueLabel(14))
                .foregroundStyle(Color.anagramOrange)
                .frame(width: iconFrame, height: iconFrame)

            Text(text)
                .font(AppFont.body(14))
                .foregroundStyle(Color.anagramInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        AnagramInstructionsContentView()
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
    }
}
