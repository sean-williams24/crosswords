import SwiftUI

struct HomeView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var puzzleService: PuzzleService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @EnvironmentObject var ratingService: OverallRatingService
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var wotdService = WOTDService()
    @StateObject private var backwordService = BackwordService()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showArchive = false
    @State private var showPaywall = false
    @State private var showWOTD = false
    @State private var showSettings = false
    @State private var navigateToPuzzle = false
    @State private var navigateToWeekly = false
    @State private var showStreakPopup = false
    @State private var logoVisible = false
    @State private var proLogoVisible = false
    #if DEBUG
    @State private var showDebugSettings = false
    #endif

    init(viewModel: HomeViewModel? = nil) {
        // Can't use @EnvironmentObject in init, so create with a temporary service
        // The real service is injected via .onAppear
        _viewModel = StateObject(wrappedValue: viewModel ?? HomeViewModel(puzzleService: PuzzleService()))
    }

    @ViewBuilder
    private var dailyCrossword: some View {
        if viewModel.todaysPuzzle != nil {
            NavigationLink(value: "puzzle") {
                dailyCrosswordCard()
            }
            .buttonStyle(.plain)
        } else {
            dailyCrosswordCard()
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        RatingBarView(
                            rating: ratingService.rating,
                            isPro: storeService.isProUser
                        )
                        .padding(.horizontal, AppLayout.screenPadding)

                        backwordButton
                        dailyCrossword
                        WeeklyCrosswordCard(viewModel: viewModel, isProUser: storeService.isProUser)
                            .environmentObject(storeService)
                        wotd
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                // Semi-transparent nav bar — extends behind status bar
                ZStack(alignment: .center) {
                    VStack(spacing: -17) {
                        BackwordLogo()
                            .offset(x: logoVisible ? 0 : 120)
                            .opacity(logoVisible ? 1 : 0)
                        if storeService.isProUser {
                            Image("Pro")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 28)
                                .offset(x: 20)
                                .opacity(proLogoVisible ? 1 : 0)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    HStack {
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18))
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding(.trailing, AppLayout.screenPadding)
                    }
                }
                #if DEBUG
                .onTapGesture(count: 3) {
                    showDebugSettings = true
                }
                #endif
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .background(
                    Color.appBackground.opacity(0.85)
                        .background(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                        .ignoresSafeArea()
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Archive footer bar
                VStack(spacing: 0) {
                    Button {
                        if storeService.isProUser {
                            showArchive = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Label("Archive", systemImage: "archivebox")
                            if !storeService.isProUser {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.appAccent)
                            }
                        }
                        .font(AppFont.clueLabel(14))
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 8)
                }
                .background {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Color.appBackground.opacity(0.75)
                    }
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
                }
            }
            .ignoresSafeArea(.keyboard)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { destination in
                if destination == "weekly",
                    let puzzle = viewModel.weeklyPuzzle {
                    PuzzleView(viewModel: GameViewModel(puzzle: puzzle))
                        .environmentObject(statsService)
                        .environmentObject(storeService)
                        .environmentObject(adService)
                        .environmentObject(ratingService)
                } else if destination == "backword",
                            let word = backwordService.todaysWord {
                    BackwordView(word: word)
                        .environmentObject(storeService)
                        .environmentObject(adService)
                } else if let puzzle = viewModel.todaysPuzzle {
                    PuzzleView(viewModel: GameViewModel(puzzle: puzzle))
                        .environmentObject(statsService)
                        .environmentObject(storeService)
                        .environmentObject(adService)
                        .environmentObject(ratingService)
                }
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
                DebugSettingsView(homeViewModel: viewModel)
                    .environmentObject(storeService)
                    .environmentObject(backwordService)
            }
            #endif
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(storeService)
            }
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
                await wotdService.refreshIfNeeded()
                await backwordService.refreshIfNeeded()
                ratingService.refresh()
                ratingService.recordCurrentPuzzles(
                    daily: viewModel.todaysPuzzle,
                    weekly: viewModel.weeklyPuzzle
                )
            }
            .task {
                // Sleep until midnight then trigger a full refresh, then repeat each day.
                while !Task.isCancelled {
                    guard let delay = secondsUntilMidnight(), delay > 0 else { break }
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { break }
                    await viewModel.loadTodaysPuzzle()
                    await wotdService.refreshIfNeeded()
                    await backwordService.refreshIfNeeded()
                    ratingService.refresh()
                    ratingService.recordCurrentPuzzles(
                        daily: viewModel.todaysPuzzle,
                        weekly: viewModel.weeklyPuzzle
                    )
                }
            }
            .onAppear {
                logoVisible = false
                proLogoVisible = false
                animateLogo()
                Task {
                    await viewModel.refreshIfNeeded(isProUser: storeService.isProUser)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background || newPhase == .inactive {
                    logoVisible = false
                    proLogoVisible = false
                } else if newPhase == .active {
                    animateLogo()
                    
                    Task {
                        await viewModel.refreshIfNeeded(isProUser: storeService.isProUser)
                        await wotdService.refreshIfNeeded()
                        await backwordService.refreshIfNeeded()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var backwordButton: some View {
        if backwordService.todaysWord != nil {
            NavigationLink(value: "backword") {
                BackwordCard(
                    word: backwordService.todaysWord,
                    progress: backwordService.todaysWord.flatMap {
                        BackwordProgress.load(date: $0.date)
                    }
                )
            }
            .buttonStyle(.plain)
        } else {
            BackwordCard(word: nil, progress: nil)
        }
    }

    private func animateLogo() {
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms — next render cycle
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                logoVisible = true
            }

            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.easeIn) {
                proLogoVisible = true
            }
        }
    }

    // MARK: - Today Card

    @ViewBuilder
    private func dailyCrosswordCard() -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                Text("DAILY CROSSWORD")
                    .font(AppFont.clueLabel(11))
                    .foregroundColor(.dailyCardTitle)
                    .tracking(3)
                    .multilineTextAlignment(.center)

                Text(formattedDate)
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
                    .tracking(1)
                    .multilineTextAlignment(.center)

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.appAccent)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.puzzleStatus.icon)
                            .foregroundColor(viewModel.puzzleStatus.color)
                            .font(.system(size: 13))
                        Text(viewModel.puzzleStatus.label)
                            .font(AppFont.caption())
                            .foregroundColor(.appTextSecondary)
                    }
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
            }
        )
        .clipped()
        .cornerRadius(AppLayout.cardCornerRadius)
        .padding(.horizontal, AppLayout.screenPadding)
    }

    // MARK: - Word of the Day Card

    @ViewBuilder
    private var wotd: some View {
        Button {
            showWOTD = true
        } label: {
            wotdCard()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func wotdCard() -> some View {
        VStack(spacing: 6) {
            Text("WORD OF THE DAY")
                .font(AppFont.clueLabel(10))
                .foregroundColor(.appTextSecondary)
                .tracking(3)

            if let word = wotdService.todaysWord {
                Text(word.word)
                    .font(AppFont.header(22))
                    .foregroundColor(.appTextPrimary)
            } else {
                ProgressView()
                    .frame(minHeight: 30)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .cornerRadius(AppLayout.cardCornerRadius)
        .padding(.horizontal, AppLayout.screenPadding)
    }

    // MARK: - Helpers

    private func secondsUntilMidnight() -> TimeInterval? {
        let calendar = Calendar.current
        guard let midnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return nil }
        return midnight.timeIntervalSinceNow
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt.string(from: Date()).uppercased()
    }

}

#Preview("Default") {
    HomeView()
        .environmentObject(PuzzleService())
        .environmentObject(StatsService())
        .environmentObject(StoreService())
        .environmentObject(AdService())
        .environmentObject(OverallRatingService())
}

#if DEBUG
#Preview("Completed Puzzle") {
    let vm = HomeViewModel(puzzleService: PuzzleService())
    vm.debugSetSampleCompleted()
    return HomeView(viewModel: vm)
        .environmentObject(PuzzleService())
        .environmentObject(StatsService())
        .environmentObject(StoreService())
        .environmentObject(AdService())
        .environmentObject(OverallRatingService())
}
#endif
