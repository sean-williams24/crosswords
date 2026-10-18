import SwiftUI

/// Measures the complete dashboard before choosing its scrolling, compact form.
struct HomeDashboardView<Expanded: View, Compact: View>: View {
    let usesTwoColumns: Bool
    @ViewBuilder var expanded: () -> Expanded
    @ViewBuilder var compact: () -> Compact

    var body: some View {
        ViewThatFits(in: .vertical) {
            if usesTwoColumns {
                expanded()
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                compact()
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
