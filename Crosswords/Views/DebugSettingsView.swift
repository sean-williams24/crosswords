#if DEBUG
import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("In-App Purchases") {
                    Toggle("Pro User", isOn: Binding(
                        get: { storeService.isProUser },
                        set: { storeService.setDebugProUser($0) }
                    ))
                }
            }
            .navigationTitle("Debug Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DebugSettingsView()
        .environmentObject(StoreService())
}
#endif
