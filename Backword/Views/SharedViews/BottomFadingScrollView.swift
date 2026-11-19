import SwiftUI

/// Fades scrolling content into the controls below while leaving the final row reachable.
struct BottomFadingScrollView<Content: View>: View {
    let fadeHeight: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .padding(.bottom, fadeHeight)
        }
        .mask {
            VStack(spacing: 0) {
                Rectangle().fill(Color.appTextPrimary)
                LinearGradient(
                    colors: [.appTextPrimary, .appTextPrimary.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: fadeHeight)
            }
        }
    }
}
