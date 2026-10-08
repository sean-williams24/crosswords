import SwiftUI

/// Bounds both typography and scaled dimensions inside a game surface.
struct GameDynamicTypeContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .dynamicTypeSize(...AppLayout.gameMaximumDynamicTypeSize)
    }
}
