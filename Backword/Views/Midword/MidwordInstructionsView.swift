import SwiftUI

struct MidwordInstructionsView: View {
    struct ScoringRule: Identifiable, Equatable {
        let label: String
        let points: String

        var id: String { label }
    }

    @ScaledMetric private var iconFrame: CGFloat = 22

    static let scoringRules = [
        ScoringRule(label: "First guess", points: "5 pts"),
        ScoringRule(label: "Second guess", points: "4 pts"),
        ScoringRule(label: "Third guess", points: "3 pts"),
        ScoringRule(label: "Fourth guess", points: "2 pts"),
        ScoringRule(label: "Fifth guess", points: "1 pt"),
        ScoringRule(label: "Not solved", points: "0 pts")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                goalSection
                sectionDivider
                exampleSection
                sectionDivider
                scoringSection
            }
            .padding(AppLayout.screenPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground)
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "link", title: "Find the connection")
            instructionRow(
                icon: "textformat.abc",
                text: "The missing middle word joins with both shown words to make two familiar compound words."
            )
            instructionRow(
                icon: "rectangle.split.3x1",
                text: "The empty letter cells show exactly how long the answer is."
            )
            instructionRow(
                icon: "book.closed",
                text: "Guesses must be valid English words. Invalid or repeated words do not use an attempt."
            )
            instructionRow(
                icon: "rectangle.stack",
                text: "You have five attempts."
            )
        }
    }

    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "checkmark.circle", title: "Example")

            Group {
                Text("Starting with two words, Bank and Book." )
                Text("NOTE is the answer because it completes both compounds.")
            }
            .font(AppFont.body(14))
            .foregroundStyle(Color.appTextPrimary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                exampleRow(parts: ["BANK", "NOTE"], result: "BANKNOTE")
                exampleRow(parts: ["NOTE", "BOOK"], result: "NOTEBOOK")
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.midwordAccent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))

        }
    }

    private var scoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "star.circle", title: "Scoring")

            ForEach(Self.scoringRules) { rule in
                HStack {
                    Text(rule.label)
                        .font(AppFont.body(14))
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    Text(rule.points)
                        .font(AppFont.clueLabel(14))
                        .foregroundStyle(Color.midwordAccent)
                }
            }

            Text("Only a solve completed on the puzzle's release day adds points to your rolling 14-day rating.")
                .font(AppFont.body(14))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(Color.midwordAccent.opacity(0.25))
    }

    private func sectionTitle(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(AppFont.clueLabel(14))
                .foregroundStyle(Color.midwordAccent)
                .frame(width: iconFrame, height: iconFrame)
            Text(title)
                .font(AppFont.clueLabel(15))
                .foregroundStyle(Color.appTextPrimary)
        }
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(AppFont.clueLabel(14))
                .foregroundStyle(Color.midwordAccent)
                .frame(width: iconFrame, height: iconFrame)
            Text(text)
                .font(AppFont.body(14))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func exampleRow(parts: [String], result: String) -> some View {
        Text("\(parts.joined(separator: " + "))  =  \(result)")
            .font(AppFont.clueLabel(16))
            .foregroundStyle(Color.midwordAccent)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("\(parts.joined(separator: " plus ")) makes \(result)")
    }
}

#Preview {
    NavigationStack {
        MidwordInstructionsView()
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
    }
}
