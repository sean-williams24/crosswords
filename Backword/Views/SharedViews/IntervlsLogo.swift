import SwiftUI

struct IntervlsLogo: View {
    @ScaledMetric var frame: CGFloat = AppLayout.brandLogoHeight

    var body: some View {
        Image(AppBrand.logoAsset)
            .resizable()
            .scaledToFit()
            .frame(height: frame)
            .accessibilityLabel(AppBrand.name)
    }
}
