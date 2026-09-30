import SwiftUI

struct HomeWordOfTheDayView: View {
    let word: WordOfTheDay?
    let showsInlineDetails: Bool
    let openDetails: () -> Void

    var body: some View {
        Group {
            if showsInlineDetails, let word {
                inlineDetails(for: word)
            } else {
                Button(action: openDetails) {
                    compactCard
                }
                .buttonStyle(.plain)
                .disabled(word == nil)
            }
        }
    }

    private var compactCard: some View {
        ZStack {
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.appTextPrimary)
            }

            VStack(spacing: 6) {
                Text("WORD OF THE DAY")
                    .font(AppFont.clueLabel(10))
                    .foregroundColor(.appTextHeading)
                    .tracking(3)

                if let word {
                    Text(word.word)
                        .font(AppFont.header(22))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    ProgressView()
                        .frame(minHeight: 30)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 30)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .accessibilityLabel(word.map { "Word of the Day: \($0.word)" } ?? "Loading Word of the Day")
    }

    private func inlineDetails(for word: WordOfTheDay) -> some View {
        HStack(alignment: .top, spacing: 36) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("WORD OF THE DAY")
                        .font(AppFont.clueLabel(11))
                        .foregroundColor(.appTextHeading)
                        .tracking(3)

                    Text(word.word)
                        .font(AppFont.header(40))
                        .foregroundColor(.appTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    ViewThatFits {
                        HStack(spacing: 8) {
                            pronunciation(for: word)
                            Text("•")
                                .foregroundColor(.appTextSecondary)
                            partOfSpeech(for: word)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            pronunciation(for: word)
                            partOfSpeech(for: word)
                        }
                    }
                }

                sectionBlock(title: "DEFINITION") {
                    Text(word.definition)
                        .font(AppFont.body())
                        .foregroundColor(.appTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 24) {
                sectionBlock(title: "EXAMPLE") {
                    Text("\u{201C}\(word.exampleSentence)\u{201D}")
                        .font(AppFont.body())
                        .italic()
                        .foregroundColor(.appTextPrimary)
                }

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
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                sectionBlock(title: "ETYMOLOGY") {
                    Text(word.etymology)
                        .font(AppFont.body())
                        .foregroundColor(.appTextPrimary)
                }

                if let explanation = word.partOfSpeechExplanation {
                    Label(explanation, systemImage: "info.circle")
                        .font(AppFont.caption())
                        .italic()
                        .foregroundColor(.appTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .accessibilityElement(children: .contain)
    }

    private func pronunciation(for word: WordOfTheDay) -> some View {
        Text(word.pronunciation)
            .font(AppFont.body())
            .foregroundColor(.appAccent)
    }

    private func partOfSpeech(for word: WordOfTheDay) -> some View {
        Text(word.partOfSpeech.capitalized)
            .font(AppFont.body())
            .italic()
            .foregroundColor(.appTextSecondary)
    }

    private func sectionBlock<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.clueLabel(11))
                .foregroundColor(.appTextSecondary)
                .tracking(2)
            content()
        }
    }
}

enum HomeWordOfTheDayLayout {
    static let minimumInlineViewportWidth: CGFloat = 901

    static func showsInlineDetails(
        viewportWidth: CGFloat,
        dynamicTypeSize: DynamicTypeSize
    ) -> Bool {
        viewportWidth >= minimumInlineViewportWidth && !dynamicTypeSize.isAccessibilitySize
    }
}
