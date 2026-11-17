import SwiftUI

struct AnalyticsSettingsSection: View {
    @EnvironmentObject private var analyticsConsent: AnalyticsConsentViewModel

    var body: some View {
        Section {
            Toggle("Share usage analytics", isOn: Binding(
                get: { analyticsConsent.isEnabled },
                set: { analyticsConsent.setEnabled($0) }
            ))
            .font(AppFont.body())
            .foregroundStyle(Color.appTextPrimary)
            .tint(.appAccent)
            .listRowBackground(Color.appSurface)
        } header: {
            Text("Analytics")
        } footer: {
            Text("Help us understand which games people play and which campaigns bring them here. Analytics is optional. You can change your choice at any time without affecting gameplay.")
                .font(AppFont.caption())
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}
