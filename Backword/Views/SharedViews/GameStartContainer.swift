import SwiftUI

enum GameStartCoordinateSpace: Hashable {
    case viewport
}

/// Centers a game's introduction in the full viewport, independently of its header.
/// Taller content expands naturally and remains reachable by scrolling.
struct GameStartContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            let headerHeight = max(0, geometry.frame(in: .named(GameStartCoordinateSpace.viewport)).minY)
            ScrollView {
                VStack(spacing: 24) {
                    content
                }
                .padding(AppLayout.screenPadding)
                .frame(maxWidth: 560)
                // Balance the space already occupied by navigation and the title.
                // Padding participates in scroll sizing when the panel cannot fit.
                .padding(.bottom, headerHeight)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
            }
        }
    }
}
