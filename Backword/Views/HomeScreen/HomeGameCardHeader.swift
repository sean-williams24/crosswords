import SwiftUI

struct HomeGameCardHeader<Identity: View, Streak: View>: View {
    let spacing: CGFloat
    @ViewBuilder var identity: () -> Identity
    @ViewBuilder var streak: () -> Streak

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            streak().hidden()
            Spacer(minLength: 0)
            identity()
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            streak()
        }
        .frame(maxWidth: .infinity)
    }
}
