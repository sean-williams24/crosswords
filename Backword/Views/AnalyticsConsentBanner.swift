import SwiftUI

struct AnalyticsConsentBanner: View {
    @EnvironmentObject private var analyticsConsent: AnalyticsConsentViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func dismissalAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.75)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayout.screenPadding / 2) {
            Text("Analytics preferences")
                .font(AppFont.clueLabel())
                .foregroundStyle(Color.appTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Help us understand which games people play and which campaigns bring them here. Analytics is optional.")
                .font(AppFont.caption())
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                consentButton("Decline", enabled: false)
                consentButton("Accept analytics", enabled: true)
            }
            Link("Privacy choices", destination: LegalLink.privacyChoices.url)
                .font(AppFont.caption())
                .tint(.appAccent)
        }
        .padding(AppLayout.screenPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func consentButton(_ title: String, enabled: Bool) -> some View {
        Button {
            withAnimation(Self.dismissalAnimation(reduceMotion: reduceMotion)) {
                analyticsConsent.setEnabled(enabled)
            }
        } label: {
            Text(title)
                .font(AppFont.body())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.appAccent)
    }
}
