import SwiftUI

struct BackwordRulesUpdateNotice: View {
    static let contentPadding: CGFloat = 16

    @ScaledMetric private var iconFrame: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Rules Updated")
                    .font(AppFont.header(22))
                    .foregroundColor(.appTextHeading)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundColor(.appAccent)
            }

            updateRow("Only the second and third wrong guesses each reveal one letter from the end.")
        }
        .padding(Self.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .strokeBorder(Color.appAccent.opacity(0.6), lineWidth: 1.5)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func updateRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.appCorrect)
                .frame(width: iconFrame, height: iconFrame)

            Text(text)
                .font(AppFont.body(14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    BackwordRulesUpdateNotice()
        .padding()
        .background(Color.appBackground)
}
