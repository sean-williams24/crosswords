#if DEBUG
import SwiftUI

struct DebugSettingsView: View {
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var backwordService: BackwordService
    @Environment(\.dismiss) private var dismiss

    var homeViewModel: HomeViewModel? = nil

    @State private var showResetBackwordConfirmation = false
    @State private var showResetDailyConfirmation = false
    @State private var showResetWeeklyConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("In-App Purchases") {
                    Toggle("Pro User", isOn: Binding(
                        get: { storeService.isProUser },
                        set: { storeService.setDebugProUser($0) }
                    ))
                }

                Section("Daily Crossword") {
                    Button {
                        if let vm = homeViewModel, let puzzle = vm.todaysPuzzle {
                            vm.debugFillAllButOne(puzzle: puzzle, isWeekly: false)
                            dismiss()
                        }
                    } label: {
                        Label("Fill All But One Answer", systemImage: "pencil.and.list.clipboard")
                    }
                    .disabled(homeViewModel?.todaysPuzzle == nil)

                    Button(role: .destructive) {
                        showResetDailyConfirmation = true
                    } label: {
                        Label("Reset Daily Puzzle", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(homeViewModel?.todaysPuzzle == nil)
                }

                Section("Pro Crossword") {
                    Button {
                        if let vm = homeViewModel, let puzzle = vm.weeklyPuzzle {
                            vm.debugFillAllButOne(puzzle: puzzle, isWeekly: true)
                            dismiss()
                        }
                    } label: {
                        Label("Fill All But One Answer", systemImage: "pencil.and.list.clipboard")
                    }
                    .disabled(homeViewModel?.weeklyPuzzle == nil)

                    Button(role: .destructive) {
                        showResetWeeklyConfirmation = true
                    } label: {
                        Label("Reset Pro Puzzle", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(homeViewModel?.weeklyPuzzle == nil)
                }

                Section("Backword") {
                    Button(role: .destructive) {
                        showResetBackwordConfirmation = true
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
                isPresented: $showResetBackwordConfirmation,
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
            .confirmationDialog(
                "Reset Daily Puzzle?",
                isPresented: $showResetDailyConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    if let vm = homeViewModel, let puzzle = vm.todaysPuzzle {
                        vm.debugResetPuzzle(puzzle: puzzle, isWeekly: false)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All progress on today's daily crossword will be cleared.")
            }
            .confirmationDialog(
                "Reset Pro Puzzle?",
                isPresented: $showResetWeeklyConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    if let vm = homeViewModel, let puzzle = vm.weeklyPuzzle {
                        vm.debugResetPuzzle(puzzle: puzzle, isWeekly: true)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All progress on the current pro crossword will be cleared.")
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
