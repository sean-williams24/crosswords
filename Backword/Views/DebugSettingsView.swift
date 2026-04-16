#if DEBUG
import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var backwordService: BackwordService
    @Environment(\..dismiss) private var dismiss

    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("In-App Purchases") {
                    Toggle("Pro User", isOn: Binding(
                        get: { storeService.isProUser },
                        set: { storeService.setDebugProUser($0) }
                    ))
                }

                Section("Backword") {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Reset Today's Backword", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Debug Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset Today's Backword?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    if let date = backwordService.todaysWord?.date {
                        BackwordProgress.delete(date: date)
                    }
                    Task { await backwordService.refreshIfNeeded(force: true) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your guesses for today will be cleared and the game will restart.")
            }
        }
    }
}

#Preview {
    DebugSettingsView()
        .environmentObject(StoreService())
        .environmentObject(BackwordService())
}
#endif
