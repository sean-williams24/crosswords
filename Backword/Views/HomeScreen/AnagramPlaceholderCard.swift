import SwiftUI

struct AnagramPlaceholderCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let isLoading: Bool
    let retry: () -> Void

    private var appLayout: AppLayout {
        AppLayout(sizeClass: sizeClass)
    }

    var body: some View {
        Group {
            if isLoading {
                content
            } else {
                Button(action: retry) { content }
                    .buttonStyle(.plain)
            }
        }
        .accessibilityLabel(isLoading ? "Loading Anagram" : "Anagram failed to load. Double tap to retry.")
    }

    private var content: some View {
        Group {
            if AnagramHomeCardLayout.usesStackedLayout(for: dynamicTypeSize) {
                VStack(alignment: .leading, spacing: AnagramHomeCardLayout.columnSpacing) {
                    title
                    detail
                }
            } else {
                HStack(alignment: .top, spacing: AnagramHomeCardLayout.columnSpacing) {
                    title
                    detail
                }
            }
        }
        .padding(.horizontal, AnagramHomeCardLayout.horizontalPadding)
        .padding(.vertical, AnagramHomeCardLayout.verticalPadding)
        .foregroundStyle(Color.anagramOnOrange)
        .frame(maxWidth: .infinity, minHeight: appLayout.cardHeight)
        .background(Color.anagramHomeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
    }

    private var title: some View {
        Text("ANAGRAM")
            .font(AppFont.clueLabel(appLayout.isiPad ? 28 : 24))
            .tracking(3)
            .lineLimit(1)
            .minimumScaleFactor(0.35)
    }

    private var detail: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.anagramOnOrange)
            } else {
                VStack(alignment: .trailing, spacing: AnagramHomeCardLayout.contentSpacing) {
                    Text("Failed to load today's puzzle.")
                        .font(AppFont.caption())
                    Label("Tap to retry", systemImage: "arrow.clockwise")
                        .font(AppFont.caption().bold())
                }
                .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
