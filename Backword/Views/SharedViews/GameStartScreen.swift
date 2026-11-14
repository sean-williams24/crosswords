import SwiftUI

/// Keeps the title and issue at the top while the panel centers in the viewport.
struct GameStartScreen<Header: View, Content: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(AppLayout.screenPadding)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            GameStartContainer {
                content
            }
        }
    }
}
