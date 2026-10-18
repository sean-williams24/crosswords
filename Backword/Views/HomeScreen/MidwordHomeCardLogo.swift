import SwiftUI

struct MidwordHomeCardLogo: View {
    @ScaledMetric private var height = AppLayout.midwordHomeCardLogoHeight

    var body: some View {
        Image("MidwordLogoLight")
            .resizable()
            .scaledToFit()
            .frame(height: height)
    }
}
