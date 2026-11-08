import SwiftUI

/// Measures the complete dashboard before choosing its scrolling, compact form.
struct HomeDashboardView<Expanded: View, Compact: View>: View {
    let usesTwoColumns: Bool
    var scrollToTopTrigger = 0
    @ViewBuilder var expanded: () -> Expanded
    @ViewBuilder var compact: () -> Compact

    private enum ScrollAnchor: Hashable { case top }

    var body: some View {
        ViewThatFits(in: .vertical) {
            if usesTwoColumns {
                expanded()
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    compact().id(ScrollAnchor.top)
                }
                .scrollIndicators(.hidden)
                .task(id: scrollToTopTrigger) {
                    guard scrollToTopTrigger > 0 else { return }
                    // The daily markers otherwise may still be above the viewport
                    // after returning from a game near the bottom of Home. Yield
                    // so the anchor is registered even if Home just reappeared.
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
