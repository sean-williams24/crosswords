import SwiftUI

struct MidwordLogo: View {
    @Environment(\.colorScheme) private var colorScheme
    var image = Image("MidwordLogo")

    var body: some View {
        image
            .renderingMode(colorScheme == .dark ? .template : .original)
            .resizable()
            .scaledToFit()
            .foregroundStyle(AppGradient.midwordLogo)
            .frame(height: 38)
    }
}
