import SwiftUI

struct AnalyticsConsentBannerPresentation: ViewModifier {
    @EnvironmentObject private var analyticsConsent: AnalyticsConsentViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDismissing = false
    @State private var bannerHeight: CGFloat = 0

    let isAvailable: Bool

    static func dismissalAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 1)
    }

    static func showsFooter(shouldShowPrompt: Bool, isDismissing: Bool) -> Bool {
        shouldShowPrompt || isDismissing
    }

    static func dismissalOffset(bannerHeight: CGFloat, bottomSafeArea: CGFloat) -> CGFloat {
        bannerHeight + bottomSafeArea
    }

    func body(content: Content) -> some View {
        let showsFooter = isAvailable && Self.showsFooter(
            shouldShowPrompt: analyticsConsent.shouldShowPrompt,
            isDismissing: isDismissing
        )

        // Reserve space independently of the visible footer so its position is stable during the slide.
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsFooter {
                    Color.clear
                        .frame(height: bannerHeight)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if showsFooter {
                    footerOverlay
                        .transition(.identity)
                }
            }
    }

    private var footerOverlay: some View {
        GeometryReader { geometry in
            let bottomSafeArea = geometry.safeAreaInsets.bottom
            let slideDistance = Self.dismissalOffset(bannerHeight: bannerHeight, bottomSafeArea: bottomSafeArea)

            AnalyticsConsentBanner(selectConsent: dismiss)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bannerHeight = $0 }
                .padding(.bottom, bottomSafeArea)
                .background(Color.appSurface, ignoresSafeAreaEdges: [])
                .offset(y: isDismissing ? slideDistance : 0)
                .allowsHitTesting(!isDismissing)
                .accessibilityHidden(isDismissing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private func dismiss(enabled: Bool) {
        guard analyticsConsent.shouldShowPrompt, !isDismissing else { return }

        if let animation = Self.dismissalAnimation(reduceMotion: reduceMotion) {
            withAnimation(animation, completionCriteria: .removed) {
                isDismissing = true
            } completion: {
                isDismissing = false
            }
        }

        analyticsConsent.setEnabled(enabled)
    }
}
