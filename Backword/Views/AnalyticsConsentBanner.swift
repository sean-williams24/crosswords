import SwiftUI

struct AnalyticsConsentBanner: View {
    let selectConsent: (Bool) -> Void

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
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func consentButton(_ title: String, enabled: Bool) -> some View {
        Button {
            selectConsent(enabled)
        } label: {
            Text(title)
                .font(AppFont.body())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, AppLayout.screenPadding / 2)
        }
        .buttonStyle(ConsentButtonStyle())
    }

    private struct ConsentButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity, minHeight: AppLayout.minimumTouchTarget)
                .background(Color.appAccent.opacity(configuration.isPressed ? 0.28 : 0.18), in: Capsule())
                .contentShape(Capsule())
        }
    }
}
