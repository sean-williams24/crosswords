import SwiftUI

struct GiveUpFlagButton: View {
    let iconSize: CGFloat
    let glyphSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "flag.fill")
                .font(AppFont.body(glyphSize))
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.7), radius: 1)
        }
        .accessibilityLabel("Give up")
    }
}
