import SwiftUI

/// Aligns a gameplay action with the trailing edge of the keyboard keys.
struct GameKeyboardActionRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, AppLayout.keyboardPadding)
    }
}
