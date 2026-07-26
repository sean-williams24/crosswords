//  BackwordInstructionsContentView.swift

import SwiftUI

struct BackwordInstructionsContentView: View {
    @Binding var mode: BackwordMode
    var showsRulesUpdateNotice = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var iconFrame: CGFloat = 20
    private let cellFrame: CGFloat = 30

    init(
        mode: Binding<BackwordMode> = .constant(.normal),
        showsRulesUpdateNotice: Bool = false
    ) {
        _mode = mode
        self.showsRulesUpdateNotice = showsRulesUpdateNotice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BackwordModeToggle(mode: $mode)

                Divider()
                    .background(Color.appGridLine)

                if showsRulesUpdateNotice && mode == .normal {
                    BackwordRulesUpdateNotice()
                }

                VStack(alignment: .leading, spacing: 10) {
                    instructionRow(number: "1", text: firstRule)
                    instructionRow(number: "2", text: secondRule)
                    instructionRow(number: "3", text: "The fewer guesses you need, the more points you score.")
                    instructionRow(number: nil, text: "The clue is a word associated with the answer, or something connected to it")
                }

                Divider()
                    .background(Color.appGridLine)

                Text(exampleCaption)
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("Answer: BUNDLE")
                    .font(AppFont.clueLabel(12))
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(revealExamples.enumerated()), id: \.offset) { example in
                        revealExampleRow(
                            label: Self.wrongGuessLabels[example.offset],
                            revealedSuffix: example.element
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Divider()
                    .background(Color.appGridLine)
                
                ScoringRuleView.backword(title: "Scoring")

            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground)
    }

    private static let wrongGuessLabels = [
        "1st wrong guess",
        "2nd wrong guess",
        "3rd wrong guess",
        "4th wrong guess"
    ]

    private var firstRule: String {
        "Correctly placed letters reveal when they form an unbroken chain from the back of the word."
    }

    private var secondRule: String {
        switch mode {
        case .normal:
            return "If your guesses do not extend that chain, the second and third wrong guesses each reveal one more letter from the end."
        case .easy:
            return "If your guesses do not extend that chain, each wrong guess reveals one more letter from the back of the word."
        }
    }

    private var revealExamples: [String] {
        switch mode {
        case .normal:
            return ["E", "LE", "DLE", "DLE"]
        case .easy:
            return ["LE", "DLE", "NDLE", "UNDLE"]
        }
    }

    private var exampleCaption: String {
        "Example of free reveals after each wrong guess"
    }

    private func revealExampleRow(label: String, revealedSuffix: String) -> some View {
        let suffix = Array(revealedSuffix)
        let hiddenCount = 6 - suffix.count

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    revealExampleLabel(label)
                    HStack {
                        Spacer()
                        revealExampleCells(suffix: suffix, hiddenCount: hiddenCount)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    revealExampleLabel(label)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    revealExampleCells(suffix: suffix, hiddenCount: hiddenCount)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func revealExampleLabel(_ label: String) -> some View {
        Text(label)
            .font(AppFont.clueLabel(12))
            .foregroundColor(.appTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func revealExampleCells(suffix: [Character], hiddenCount: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { index in
                let suffixIndex = index - hiddenCount
                exampleCell(
                    letter: suffixIndex >= 0 ? String(suffix[suffixIndex]) : "",
                    isRevealed: suffixIndex >= 0
                )
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func instructionRow(number: String?, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let number {
                Text(number)
                    .font(AppFont.clueLabel(13))
                    .foregroundColor(.white)
                    .frame(width: iconFrame, height: iconFrame)
                    .background(Color.appAccent)
                    .clipShape(Circle())
            } else {
                Image(systemName: "info.circle")
                    .foregroundColor(.appCorrect)
            }
            Text(text)
                .font(AppFont.body(14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exampleCell(letter: String, isRevealed: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isRevealed ? Color.appAccent.opacity(0.5) : Color.appGridLine,
                            lineWidth: 1.5
                        )
                )
            Text(isRevealed ? letter : "")
                .font(AppFont.gridLetter(16))
                .foregroundColor(.appTextPrimary)
        }
        .frame(width: cellFrame, height: cellFrame)
    }
}

#Preview {
    BackwordInstructionsContentView()
}
