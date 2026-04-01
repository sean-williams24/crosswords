import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    letterFeedbackRow
                } header: {
                    Text("BACKWORD")
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appAccent)
                        .tracking(2)
                        .textCase(nil)
                } footer: {
                    Text("When enabled, letters in your past guesses that appear anywhere in the target word are highlighted.")
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
        }
    }

    private var letterFeedbackRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Letter Feedback")
                        .font(AppFont.body(15))
                        .foregroundColor(storeService.isProUser ? .appTextPrimary : .appTextSecondary)

                    if !storeService.isProUser {
                        proTag
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { settings.backwordLetterFeedback },
                set: { newValue in
                    guard storeService.isProUser else { return }
                    settings.backwordLetterFeedback = newValue
                }
            ))
            .tint(.appAccent)
            .disabled(!storeService.isProUser)
        }
        .listRowBackground(Color.appSurface)
    }

    private var proTag: some View {
        Text("PRO")
            .font(AppFont.clueLabel(9))
            .foregroundColor(.appAccent)
            .tracking(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.appAccent, lineWidth: 1)
            )
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreService())
}
