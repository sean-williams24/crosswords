#if DEBUG
import SwiftUI
import TipKit

struct DebugSettingsView: View {
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var backwordService: BackwordService
    @EnvironmentObject var wotdService: WOTDService
    @EnvironmentObject var adService: AdService
    @Environment(\.dismiss) private var dismiss

    var homeViewModel: HomeViewModel? = nil
    private let settings = AppSettings.shared

    @State private var showResetBackwordConfirmation = false
    @State private var showResetDailyConfirmation = false
    @State private var showResetWeeklyConfirmation = false
    @State private var showResetUserDefaultsConfirmation = false
    @State private var showPurgeDailyConfirmation = false
    @State private var showPurgeWeeklyConfirmation = false
    @State private var showPurgeBackwordConfirmation = false
    @State private var showPurgeWOTDConfirmation = false
    @State private var showOnboardingResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("In-App Purchases") {
                    Toggle("Pro User", isOn: Binding(
                        get: { storeService.isProUser },
                        set: { storeService.setDebugProUser($0) }
                    ))
                }

                /// Google Ads
                Section("Ads") {
                    Toggle("Ads Enabled", isOn: Binding(
                        get: { adService.debugAdsEnabled },
                        set: { adService.setDebugAdsEnabled($0) }
                    ))
                    Button(role: .destructive) {
                        showResetUserDefaultsConfirmation = true
                    } label: {
                        Label("Reset User Deafults", systemImage: "arrow.counterclockwise")
                    }
                }
                .confirmationDialog(
                    "Reset defaults",
                    isPresented: $showResetUserDefaultsConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        adService.resetUserDefaults()
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All 3 user defaults values will be reset.")
                }

                /// Daily Crossword
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

                /// Pro Crossword
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

                /// Backword
                Section("Backword") {
                    Button(role: .destructive) {
                        showResetBackwordConfirmation = true
                    } label: {
                        Label("Reset Today's Backword", systemImage: "arrow.counterclockwise")
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


                // MARK: - Onboarding

                Section("Onboarding") {
                    Button(role: .destructive) {
                        showOnboardingResetConfirmation = true
                    } label: {
                        Label("Reset onboarding flags", systemImage: "trash")
                    }
                }
                confirmationDialog(
                    "Reset onboarding flags?",
                    isPresented: $showOnboardingResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        try? Tips.resetDatastore()
                        try? Tips.configure([
                            .datastoreLocation(.applicationDefault)
                        ])
                        settings.hasSeenBackwordOnboarding = false
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Onboarding tooltips and user defaults flags will be reset.")
                }

                // MARK: - Cache

                Section("Cache") {
                    Button(role: .destructive) {
                        showPurgeDailyConfirmation = true
                    } label: {
                        Label("Purge Daily Crossword", systemImage: "trash")
                    }
                    Button(role: .destructive) {
                        showPurgeWeeklyConfirmation = true
                    } label: {
                        Label("Purge Weekly Crossword", systemImage: "trash")
                    }
                    Button(role: .destructive) {
                        showPurgeBackwordConfirmation = true
                    } label: {
                        Label("Purge Backword", systemImage: "trash")
                    }
                    Button(role: .destructive) {
                        showPurgeWOTDConfirmation = true
                    } label: {
                        Label("Purge Word of the Day", systemImage: "trash")
                    }
                }
                .confirmationDialog(
                    "Purge Daily Crossword?",
                    isPresented: $showPurgeDailyConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Purge", role: .destructive) {
                        Task {
                            await homeViewModel?.debugPurgeDailyPuzzle()
                        }
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The cached daily crossword will be deleted. The app will fetch a fresh copy from Supabase.")
                }
                .confirmationDialog(
                    "Purge Weekly Crossword?",
                    isPresented: $showPurgeWeeklyConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Purge", role: .destructive) {
                        Task {
                            await homeViewModel?.debugPurgeWeeklyPuzzle()
                        }
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The cached weekly crossword will be deleted. The app will fetch a fresh copy from Supabase.")
                }
                .confirmationDialog(
                    "Purge Backword?",
                    isPresented: $showPurgeBackwordConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Purge", role: .destructive) {
                        Task { await backwordService.purgeCache() }
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The cached Backword will be deleted. The app will fetch a fresh copy from Supabase.")
                }
                .confirmationDialog(
                    "Purge Word of the Day?",
                    isPresented: $showPurgeWOTDConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Purge", role: .destructive) {
                        Task { await wotdService.purgeCache() }
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The cached Word of the Day will be deleted. The app will fetch a fresh copy from Supabase.")
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
        .environmentObject(BackwordService())
        .environmentObject(WOTDService())
        .environmentObject(AdService())
}
#endif
