import SwiftUI

struct HomeView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var puzzleService: PuzzleService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var wotdService = WOTDService()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showStats = false
    @State private var showArchive = false
    @State private var showPaywall = false
    @State private var showWOTD = false
    @State private var navigateToPuzzle = false
    @State private var navigateToWeekly = false
    @State private var showStreakPopup = false
    #if DEBUG
    @State private var showDebugSettings = false
    #endif

    init() {
        // Can't use @EnvironmentObject in init, so create with a temporary service
        // The real service is injected via .onAppear
        _viewModel = StateObject(wrappedValue: HomeViewModel(puzzleService: PuzzleService()))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // App title
                    VStack(spacing: 4) {
                        Text("CROSSWORDS")
                            .font(AppFont.header(36))
                            .foregroundColor(.appTextPrimary)
                            .tracking(4)
                        if storeService.isProUser {
                            Text("PRO")
                                .font(AppFont.header(36))
                                .foregroundColor(.appTextPrimary)
                                .tracking(4)
                        }
                    }
                    .multilineTextAlignment(.center)
                    #if DEBUG
                    .onTapGesture(count: 3) {
                        showDebugSettings = true
                    }
                    #endif
                    .padding()

                    // Word of the Day
                    if let word = wotdService.todaysWord {
                        Button {
                            showWOTD = true
                        } label: {
                            wotdCard(word: word)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Today's puzzle card
                    if viewModel.todaysPuzzle != nil {
                        NavigationLink(value: "puzzle") {
                            dailyCrosswordCard(puzzle: viewModel.todaysPuzzle!)
                        }
                        .buttonStyle(.plain)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .tint(.appAccent)
                    }

                    // Weekly puzzle card (pro only)
                    if let weekly = viewModel.weeklyPuzzle {
                        if storeService.isProUser {
                            NavigationLink(value: "weekly") {
                                weeklyCard(puzzle: weekly)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                weeklyCard(puzzle: weekly, locked: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    // Bottom buttons
                    HStack(spacing: 12) {
                        Button {
                            showStats = true
                        } label: {
                            Label("Stats", systemImage: "chart.bar")
                                .font(AppFont.clueLabel(14))
                                .foregroundColor(.appTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.appSurface)
                                .cornerRadius(AppLayout.cardCornerRadius)
                        }

                        Button {
                            if storeService.isProUser {
                                showArchive = true
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Archive", systemImage: "archivebox")
                               if !storeService.isProUser {
                                   Image(systemName: "lock.fill")
                                       .font(.system(size: 12))
                                       .foregroundColor(.appAccent)
                               }
                                Spacer()

                            }
                            .font(AppFont.clueLabel(14))
                            .foregroundColor(.appTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color.appSurface)
                            .cornerRadius(AppLayout.cardCornerRadius)
                        }
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.bottom, 32)
                }
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "weekly", let puzzle = viewModel.weeklyPuzzle {
                    PuzzleView(viewModel: GameViewModel(puzzle: puzzle))
                        .environmentObject(statsService)
                        .environmentObject(storeService)
                        .environmentObject(adService)
                } else if let puzzle = viewModel.todaysPuzzle {
                    PuzzleView(viewModel: GameViewModel(puzzle: puzzle))
                        .environmentObject(statsService)
                        .environmentObject(storeService)
                        .environmentObject(adService)
                }
            }
            .sheet(isPresented: $showStats) {
                StatsView()
                    .environmentObject(statsService)
            }
            .fullScreenCover(isPresented: $showArchive) {
                ArchiveView()
                    .environmentObject(puzzleService)
                    .environmentObject(statsService)
                    .environmentObject(storeService)
                    .environmentObject(adService)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(storeService)
            }
            #if DEBUG
            .sheet(isPresented: $showDebugSettings) {
                DebugSettingsView()
                    .environmentObject(storeService)
            }
            #endif
            .sheet(isPresented: $showWOTD, onDismiss: {
                if !storeService.isProUser {
//                    adService.showInterstitial() // TODO: Re-enable
                }
            }) {
                if let word = wotdService.todaysWord {
                    WOTDDetailView(word: word)
                }
            }
            .task {
                await viewModel.refreshIfNeeded(isProUser: storeService.isProUser)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task { await viewModel.refreshIfNeeded(isProUser: storeService.isProUser) }
                }
            }
        }
    }

    // MARK: - Today Card

    @ViewBuilder
    private func dailyCrosswordCard(puzzle: Puzzle) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                Text("DAILY CROSSWORD")
                    .font(AppFont.clueLabel(11))
                    .foregroundColor(.dailyCardTitle)
                    .tracking(3)

                Text(formattedDate)
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
                    .tracking(1)

                HStack(spacing: 6) {
                    Image(systemName: viewModel.puzzleStatus.icon)
                        .foregroundColor(viewModel.puzzleStatus.color)
                        .font(.system(size: 13))
                    Text(viewModel.puzzleStatus.label)
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)

            if statsService.stats.liveCurrentStreak > 0 {
                Button {
                    showStreakPopup.toggle()
                    if showStreakPopup {
                        Task {
                            try? await Task.sleep(nanoseconds: 4_000_000_000)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showStreakPopup = false
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11))
                        Text("\(statsService.stats.liveCurrentStreak)")
                            .font(AppFont.clueLabel(12))
                            .foregroundColor(.appTextPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appSurface.opacity(0.8))
                    .cornerRadius(14)
                    .padding(12)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) {
                    if showStreakPopup {
                        Text("\(statsService.stats.liveCurrentStreak)-day streak")
                            .font(AppFont.clueLabel(12))
                            .foregroundColor(.appTextPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appSurface)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                            .offset(y: -36)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showStreakPopup)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Color.dailyCardBackground
                MiniGridPattern()
                    .opacity(0.05)
            }
        )
        .clipped()
        .cornerRadius(AppLayout.cardCornerRadius)
        .padding(.horizontal, AppLayout.screenPadding)
    }

    // MARK: - Weekly Card

    private var proGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.85, green: 0.65, blue: 0.25),
                Color(red: 0.78, green: 0.52, blue: 0.20),
                Color(red: 0.85, green: 0.65, blue: 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func weeklyCard(puzzle: Puzzle, locked: Bool = false) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(proGradient)
                Text("PRO CROSSWORD")
                    .font(AppFont.clueLabel(11))
                    .foregroundStyle(proGradient)
                    .tracking(3)
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(proGradient)
            }

            Text("13×13")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)

            if !locked {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.weeklyPuzzleStatus.icon)
                        .foregroundColor(viewModel.weeklyPuzzleStatus.color)
                        .font(.system(size: 13))
                    Text(viewModel.weeklyPuzzleStatus.label)
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                }
            } else {
                HStack(spacing: 6) {
                    Text("Pro Only")
                        .font(AppFont.caption())
                        .foregroundColor(.appAccent)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.appAccent)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            Color.appSurface.overlay(
                proGradient.opacity(0.02)
            )
        )
        .cornerRadius(AppLayout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .stroke(proGradient, lineWidth: 1.5)
        )
        .padding(.horizontal, AppLayout.screenPadding)
    }

    // MARK: - Word of the Day Card

    @ViewBuilder
    private func wotdCard(word: WordOfTheDay) -> some View {
        VStack(spacing: 6) {
            Text("WORD OF THE DAY")
                .font(AppFont.clueLabel(10))
                .foregroundColor(.appTextSecondary)
                .tracking(3)

            Text(word.word)
                .font(AppFont.header(22))
                .foregroundColor(.appTextPrimary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .cornerRadius(AppLayout.cardCornerRadius)
        .padding(.horizontal, AppLayout.screenPadding)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt.string(from: Date()).uppercased()
    }

}

#Preview {
    HomeView()
        .environmentObject(PuzzleService())
        .environmentObject(StatsService())
        .environmentObject(StoreService())
        .environmentObject(AdService())
}
