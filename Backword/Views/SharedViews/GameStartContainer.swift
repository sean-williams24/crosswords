import SwiftUI

/// Centers a game's introduction in the space below its navigation controls.
/// Taller content expands naturally and remains reachable by scrolling.
struct GameStartContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    content
                }
                .padding(AppLayout.screenPadding)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
            }
        }
    }
}
