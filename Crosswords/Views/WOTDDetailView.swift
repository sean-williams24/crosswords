import SwiftUI

struct WOTDDetailView: View {
    let word: WordOfTheDay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Word header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(word.word)
                            .font(AppFont.header(32))
                            .foregroundColor(.appTextPrimary)

                        HStack(spacing: 8) {
                            Text(word.pronunciation)
                                .font(AppFont.clueText(15))
                                .foregroundColor(.appAccent)

                            Text("•")
                                .foregroundColor(.appTextSecondary)

                            Text(word.partOfSpeech)
                                .font(AppFont.clueText(15))
                                .italic()
                                .foregroundColor(.appTextSecondary)
                        }
                    }

                    // Definition
                    sectionBlock(title: "DEFINITION") {
                        Text(word.definition)
                            .font(AppFont.body())
                            .foregroundColor(.appTextPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 19)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface)/*.opacity(0.75)*/
                    .overlay(
                        RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                            .stroke(Color.appAccent.opacity(0.6), lineWidth: 2)
                    )
                    .cornerRadius(AppLayout.cardCornerRadius)
                    .shadow(color: Color(UIColor { traits in
                        traits.userInterfaceStyle == .dark
                            ? UIColor.white.withAlphaComponent(0.22)
                            : UIColor.black.withAlphaComponent(0.22)
                    }), radius: 4, x: 0, y: 3)

                    // Example
                    sectionBlock(title: "EXAMPLE") {
                        Text("\u{201C}\(word.exampleSentence)\u{201D}")
                            .font(AppFont.clueText())
                            .italic()
                            .foregroundColor(.appTextPrimary)
                    }
                    .padding(.horizontal, 14)


                    // Synonyms
                    if !word.synonyms.isEmpty {
                        sectionBlock(title: "SYNONYMS") {
                            FlowLayout(spacing: 8) {
                                ForEach(word.synonyms, id: \.self) { synonym in
                                    Text(synonym)
                                        .font(AppFont.caption())
                                        .foregroundColor(.appAccent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.appAccent.opacity(0.1))
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                    }

                    // Etymology
                    sectionBlock(title: "ETYMOLOGY") {
                        Text(word.etymology)
                            .font(AppFont.clueText())
                            .foregroundColor(.appTextPrimary)
                    }
                    .padding(.horizontal, 14)


                    // Part of speech explainer
                    if let explainer = partOfSpeechExplainer(word.partOfSpeech) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.appTextSecondary)

                            Text(explainer)
                                .font(AppFont.caption(12))
                                .foregroundColor(.appTextSecondary)
                                .italic()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.appBackground.opacity(0.2))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.clueLabel(11))
                .foregroundColor(.appTextSecondary)
                .tracking(2)

            content()
        }
//        .padding(.horizontal, 14)
//        .padding(.vertical, 10)
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(Color.appSurface)
//        .cornerRadius(AppLayout.cardCornerRadius)
    }

    private func partOfSpeechExplainer(_ pos: String) -> String? {
        switch pos.lowercased() {
        case "noun":
            return "Noun: a word that names a person, place, thing, or idea."
        case "verb":
            return "Verb: a word that describes an action, state, or occurrence."
        case "adjective":
            return "Adjective: a describing word that modifies a noun."
        case "adverb":
            return "Adverb: a word that modifies a verb, adjective, or other adverb — often ending in -ly."
        case "pronoun":
            return "Pronoun: a word used in place of a noun, such as he, she, or it."
        case "preposition":
            return "Preposition: a word that shows the relationship between a noun and other words, such as in, on, or at."
        case "conjunction":
            return "Conjunction: a word that connects words, phrases, or clauses — such as and, but, or or."
        case "interjection":
            return "Interjection: a word or phrase that expresses strong emotion, such as oh! or wow!"
        default:
            return nil
        }
    }
}

// MARK: - Flow Layout for synonym tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

#Preview {
    WOTDDetailView(word: WordOfTheDay(
        word: "Petrichor",
        pronunciation: "PET-ri-kor",
        partOfSpeech: "noun",
        definition: "The pleasant, earthy smell produced when rain falls on dry soil.",
        etymology: "Coined in 1964 from Greek 'petra' (stone) and 'ichor' (the fluid that flows in the veins of the gods).",
        synonyms: ["earth scent", "rain smell"],
        exampleSentence: "After weeks of drought, the first drops of rain released a glorious petrichor across the garden."
    ))
}
