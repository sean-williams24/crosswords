import SwiftUI

/// Game columns depend on width independently of the Word of the Day layout.
struct HomeGamesView<TwoColumn: View, Stacked: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder var twoColumn: () -> TwoColumn
    @ViewBuilder var stacked: () -> Stacked

    var body: some View {
        if sizeClass == .regular {
            twoColumn()
        } else {
            stacked()
        }
    }
}
