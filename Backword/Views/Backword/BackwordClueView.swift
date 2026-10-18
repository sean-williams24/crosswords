import SwiftUI

struct BackwordClueView: View {
    let clue: String

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize > .accessibility1 {
                VStack(alignment: .center) {
                    clueContent
                }
            } else {
                HStack(spacing: 6) {
                    clueContent
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Clue: \(clue)")
    }

    @ViewBuilder
    private var clueContent: some View {
        Text("Clue: ")
            .font(AppFont.clueLabel(sizeClass == .regular ? 25 : 16))
            .foregroundColor(.appAccent)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)

        Text(clue.uppercased())
            .font(AppFont.clueLabel(sizeClass == .regular ? 30 : 19))
            .foregroundColor(.appTextPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}
