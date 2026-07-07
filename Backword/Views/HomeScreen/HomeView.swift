import SwiftUI
import TipKit

struct HomeView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var puzzleService: PuzzleService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @EnvironmentObject var ratingService: OverallRatingService
    @ObservedObject private var viewModel: HomeViewModel
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var wotdService = WOTDService()
    @StateObject private var backwordService = BackwordService()
    @StateObject private var backwordStatsService = BackwordStatsService()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.launchSplashDidComplete) private var launchSplashDidComplete
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @ScaledMetric var proLogoFrame: CGFloat = 18
    @ScaledMetric var navBarVStackSpacing: CGFloat = -12
    @ScaledMetric var navBarProLogoOffset: CGFloat = 20
    @State private var showArchive = false
    @State private var showPaywall = false
    @State private var showWOTD = false
    @State private var showSettings = false
    @State private var logoVisible = false
    @State private var proLogoVisible = false
    @State private var showRatingDetails = false
    @State private var navigationPath = [String]()
    @State private var navigationBarDidAppear = false
    @State private var settingsTipReadinessTask: Task<Void, Never>?
    @State private var hasOpenedDailyGameThisSession = false
    @State private var didReturnFromDailyGame = false
    @State private var showAdExplainer = false
    @State private var pendingAdExplainerGame: DailyGame?
    @State private var adExplainerGameToOpenOnDismiss: DailyGame?
    @State private var showPaywallAfterAdExplainerDismiss = false
    @State private var adExplainerDoNotShowAgain = false
    #if DEBUG
    @State private var showDebugSettings = false
    #endif

    private var appLayout: AppLayout {
        AppLayout(sizeClass: sizeClass)
    }

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackgroundGradient()

                ScrollView {
                    VStack(spacing: 20) {
                        RatingBarView(
                            rating: ratingService.rating,
                            isPro: storeService.isProUser
                        )
                        .padding(.horizontal, appLayout.homeHorizontalPadding)
                        .padding(.bottom, dynamicTypeSize > .accessibility3 ? 16 : 0)

                        dailyGamesView
                        adFreeExperienceButton
                        wotd
                        weeklyGamesView
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                navigationBar
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                archiveFooterBar
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
                } else if destination == "puzzle",
                          let puzzle = viewModel.todaysPuzzle {
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
                    .environmentObject(ratingService)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(storeService)
            }
            .sheet(isPresented: $showRatingDetails) {
                RatingDetailSheet(rating: ratingService.rating, isPro: storeService.isProUser) {
                    showRatingDetails = false
                }
            }
            #if DEBUG
            .sheet(isPresented: $showDebugSettings) {
                DebugSettingsView(homeViewModel: viewModel)
                    .environmentObject(storeService)
                    .environmentObject(backwordService)
                    .environmentObject(adService)
                    .environmentObject(wotdService)
            }
            #endif
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(storeService)
            }
            .sheet(isPresented: $showWOTD) {
                if let word = wotdService.todaysWord {
                    WOTDDetailView(word: word)
                }
            }
            .fullScreenCover(isPresented: $showAdExplainer, onDismiss: handleAdExplainerDismiss) {
                if let pendingAdExplainerGame {
                    AdExplainerView(
                        doNotShowAgain: $adExplainerDoNotShowAgain,
                        gameName: pendingAdExplainerGame.displayName,
                        close: closeAdExplainer,
                        play: playFromAdExplainer,
                        showAdFreeExperience: showAdFreeExperienceFromExplainer
                    )
                }
            }
            .task {
                await viewModel.refreshIfNeeded()
                await wotdService.refreshIfNeeded()
                await backwordService.refreshIfNeeded()
                await viewModel.prefetchCurrentArchiveMonthIfNeeded()
                backwordStatsService.refresh()
                ratingService.refresh()
                ratingService.recordCurrentPuzzles(
                    daily: viewModel.todaysPuzzle,
                    weekly: viewModel.weeklyPuzzle
                )
            }
            .task {
                // Sleep until local midnight then trigger a full refresh, then repeat each day.
                while !Task.isCancelled {
                    guard let delay = secondsUntilMidnight(), delay > 0 else { break }
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { break }
                    await viewModel.loadTodaysPuzzle()
                    await wotdService.refreshIfNeeded()
                    await backwordService.refreshIfNeeded()
                    await viewModel.prefetchCurrentArchiveMonthIfNeeded()
                    backwordStatsService.refresh()
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
                updateSettingsTipReadiness()
                animateLogo()
                Task {
                    await viewModel.refreshIfNeeded()
                    await viewModel.prefetchCurrentArchiveMonthIfNeeded()
                    backwordStatsService.refresh()
                }
            }
            .onChange(of: launchSplashDidComplete) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: adService.adStartupDidComplete) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: adService.isPresentingFullScreenAd) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: navigationPath) { oldPath, newPath in
                if !oldPath.isEmpty, newPath.isEmpty, hasOpenedDailyGameThisSession {
                    didReturnFromDailyGame = true
                    backwordStatsService.refresh()
                }
                updateSettingsTipReadiness()
            }
            .onChange(of: showArchive) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: showPaywall) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: showWOTD) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: showAdExplainer) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: showSettings) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: showRatingDetails) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: scenePhase) { _, newPhase in
                updateSettingsTipReadiness()
                if newPhase == .background || newPhase == .inactive {
                    logoVisible = false
                    proLogoVisible = false
                } else if newPhase == .active {
                    animateLogo()

                    guard !adService.isPresentingFullScreenAd else { return }

                    Task {
                        await storeService.updateSubscriptionStatus(source: "scene_active")
                        await viewModel.refreshIfNeeded()
                        await wotdService.refreshIfNeeded()
                        await backwordService.refreshIfNeeded()
                        await viewModel.prefetchCurrentArchiveMonthIfNeeded()
                    }
                }
            }
            .alert("There was a problem loading the games, please check your network.", isPresented: $viewModel.crosswordsFetchDidFail) {
                Button("OK", role: .cancel) { }
                Button("Try again") {
                    Task {
                        await viewModel.loadTodaysPuzzle()
                    }
                }
            }
        }
    }

    private func dateView(for date: String) -> some View {
        Text(date)
            .font(AppFont.caption())
            .foregroundColor(Color.appTextSecondary)
            .tracking(1)
            .multilineTextAlignment(.leading)
            .padding(.bottom, 26)
    }

    @ViewBuilder
    private var dailyGamesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Daily Games")
                .font(AppFont.header(20))
                .foregroundColor(.appTextHeading)
                .padding(.bottom, 6)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                dateView(for: dailyReleaseLabel(at: context.date))
            }

            if sizeClass == .regular {
                HStack(spacing: 45) {
                    backwordCard
                    dailyCrosswordCard
                }
                .padding(.bottom, 60)
            } else {
                Group {
                    backwordCard
//                        .shadow(color: .primary, radius: 2, x: 0, y: 1)
                        .padding(.bottom, 20)
                    dailyCrosswordCard
                }
            }
        }
        .padding(.horizontal, appLayout.homeHorizontalPadding)

    }

    @ViewBuilder
    private var weeklyGamesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Weekly Games")
                .font(AppFont.header(20))
                .foregroundColor(.appTextHeading)
                .padding(.top, isIpad ? 6 : 0)
                .padding(.bottom, 6)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                dateView(for: weeklyRefreshLabel(at: context.date))
            }
            .padding(.bottom, isIpad ? 16 : 0)

            WeeklyCrosswordCard(viewModel: viewModel, isProUser: storeService.isProUser)
                .environmentObject(storeService)
        }
        .padding(.horizontal, appLayout.homeHorizontalPadding)
    }

    @ViewBuilder
    private var navigationBar: some View {
        ZStack(alignment: .center) {
            VStack(spacing: navBarVStackSpacing) {
                BackwordLogo()
                    .offset(x: logoVisible ? 0 : 120)
                    .opacity(logoVisible ? 1 : 0)
                if storeService.isProUser {
                    Image("Pro")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: proLogoFrame)
                        .offset(x: navBarProLogoOffset)
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
                        .font(.body)
                        .foregroundColor(.appTextSecondary)
                }
                .popoverTip(SettingsTip())
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
        .onAppear {
            navigationBarDidAppear = true
            updateSettingsTipReadiness()
        }
        .onDisappear {
            navigationBarDidAppear = false
            updateSettingsTipReadiness()
        }
    }

    @ViewBuilder
    private var archiveFooterBar: some View {
        HomeTabBarView(
            isProUser: storeService.isProUser,
            showArchive: {
                if storeService.isProUser {
                    showArchive = true
                } else {
                    showPaywall = true
                }
            },
            showStats: {
                showRatingDetails = true
            }
        )
    }

    private var backwordCard: some View {
        BackwordCard(
            service: backwordService,
            progress: backwordService.todaysWord.flatMap {
                BackwordProgress.load(date: $0.date)
            }
        ) {
            openDailyGame(.backword)
        }
        .environmentObject(backwordStatsService)
    }

    private var dailyCrosswordCard: some View {
        DailyCrosswordCard(viewModel: viewModel) {
            openDailyGame(.crossword)
        }
    }

    @ViewBuilder
    private var adFreeExperienceButton: some View {
        if AdFreeExperienceButtonVisibility.shouldShow(
            isProUser: storeService.isProUser,
            subscriptionStatusLoaded: storeService.subscriptionStatusLoaded
        ) {
            AdFreeExperienceButton {
                showPaywall = true
            }
            .padding(.horizontal, appLayout.homeHorizontalPadding)
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

    private func updateSettingsTipReadiness() {
        settingsTipReadinessTask?.cancel()
        SettingsTip.homeChromeReady = false

        guard settingsTipCanPresent else { return }

        settingsTipReadinessTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            SettingsTip.homeChromeReady = settingsTipCanPresent
        }
    }

    private var settingsTipCanPresent: Bool {
        SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: launchSplashDidComplete,
            navigationBarDidAppear: navigationBarDidAppear,
            adStartupDidComplete: adService.adStartupDidComplete,
            isPresentingFullScreenAd: adService.isPresentingFullScreenAd,
            isHomeNavigationActive: homeHasActivePresentation,
            didReturnFromDailyGame: didReturnFromDailyGame
        )
    }

    private var homeHasActivePresentation: Bool {
        !navigationPath.isEmpty
            || showArchive
            || showPaywall
            || showWOTD
            || showAdExplainer
            || showSettings
            || showRatingDetails
    }

    private func openDailyGame(_ game: DailyGame) {
        if shouldShowAdExplainer(for: game) {
            cancelSettingsTipPresentation()
            pendingAdExplainerGame = game
            adExplainerDoNotShowAgain = false
            showAdExplainer = true
        } else {
            showInterstitialThenNavigate(to: game)
        }
    }

    private func shouldShowAdExplainer(for game: DailyGame) -> Bool {
        guard shouldUseAdGate(for: game) else { return false }
        return AdExplainerPresentationPolicy.shouldShow(
            isProUser: storeService.isProUser,
            hasDismissedExplainer: settings.hasDismissedAdExplainer,
            isInterstitialEligibleToday: adService.canShowInterstitialToday(for: game.adPlacement)
        )
    }

    private func closeAdExplainer() {
        showAdExplainer = false
        adExplainerGameToOpenOnDismiss = nil
        showPaywallAfterAdExplainerDismiss = false
    }

    private func playFromAdExplainer() {
        guard let game = pendingAdExplainerGame else {
            closeAdExplainer()
            return
        }

        if adExplainerDoNotShowAgain {
            settings.hasDismissedAdExplainer = true
        }

        showAdExplainer = false
        adExplainerGameToOpenOnDismiss = game
    }

    private func showAdFreeExperienceFromExplainer() {
        showPaywallAfterAdExplainerDismiss = true
        adExplainerGameToOpenOnDismiss = nil
        showAdExplainer = false
    }

    private func handleAdExplainerDismiss() {
        let game = adExplainerGameToOpenOnDismiss
        let shouldShowPaywall = showPaywallAfterAdExplainerDismiss
        adExplainerGameToOpenOnDismiss = nil
        showPaywallAfterAdExplainerDismiss = false
        pendingAdExplainerGame = nil
        adExplainerDoNotShowAgain = false

        if shouldShowPaywall {
            showPaywall = true
        } else if let game {
            showInterstitialThenNavigate(to: game)
        }
    }

    private func showInterstitialThenNavigate(to game: DailyGame) {
        guard shouldUseAdGate(for: game) else {
            navigate(to: game)
            return
        }

        adService.showInterstitialOnce(for: game.adPlacement) {
            navigate(to: game)
        }
    }

    private func shouldUseAdGate(for game: DailyGame) -> Bool {
        guard !storeService.isProUser else { return false }
        if game == .backword {
            return settings.hasSeenBackwordOnboarding
        }
        return true
    }

    private func navigate(to game: DailyGame) {
        switch game {
        case .backword:
            navigateToBackword()
        case .crossword:
            navigateToDailyCrossword()
        }
    }

    private func navigateToBackword() {
        cancelSettingsTipPresentation()
        hasOpenedDailyGameThisSession = true
        navigationPath.append("backword")
    }

    private func navigateToDailyCrossword() {
        cancelSettingsTipPresentation()
        hasOpenedDailyGameThisSession = true
        navigationPath.append("puzzle")
    }

    private func cancelSettingsTipPresentation() {
        settingsTipReadinessTask?.cancel()
        SettingsTip.homeChromeReady = false
    }

    // MARK: - Word of the Day Card

    private var chevronRight: some View {
        HStack {
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.primary)
        }
    }

    @ViewBuilder
    private var wotd: some View {
        Button {
            showWOTD = true
        } label: {
            wotdCard()
        }
        .buttonStyle(.plain)
        .disabled(wotdService.todaysWord == nil)
    }

    @ViewBuilder
    private func wotdCard() -> some View {
        ZStack {
            chevronRight

            HStack {
                Spacer()
                    .frame(width: 30)

                VStack(spacing: 6) {
                    Text("WORD OF THE DAY")
                        .font(AppFont.clueLabel(10))
                        .foregroundColor(.appTextHeading)
                        .tracking(3)
                        .multilineTextAlignment(.center)

                    if let word = wotdService.todaysWord {
                        Text(word.word)
                            .font(AppFont.header(22))
                            .foregroundColor(.appTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        ProgressView()
                            .frame(minHeight: 30)
                    }
                }
                Spacer()
                    .frame(width: 30)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .cornerRadius(AppLayout.cardCornerRadius)
        .padding(.horizontal, appLayout.homeHorizontalPadding)
        .padding(.bottom, isIpad ? 16 : 0)
    }

    private var isIpad: Bool {
        sizeClass == .regular
    }

    // MARK: - Helpers

    private func secondsUntilMidnight() -> TimeInterval? {
        ContentReleaseCalendar().secondsUntilDailyRefresh()
    }

    private func dailyReleaseLabel(at date: Date = Date()) -> String {
        let releaseCalendar = ContentReleaseCalendar(now: date)
        guard let seconds = releaseCalendar.secondsUntilDailyRefresh(),
              seconds <= 3_600
        else {
            return releaseCalendar.formattedToday
        }

        let totalMinutes = max(0, Int(seconds / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0
            ? String(format: "Resets in %d:%02d", hours, minutes)
            : String(format: "%d minutes remaining", minutes)
    }

    /// Returns a label like "Refreshes Sundays at midnight" for the local weekly reset.
    private func weeklyRefreshLabel(at date: Date = Date()) -> String {
        _ = date
        return "Refreshes Sundays at midnight"
    }
}

private enum DailyGame {
    case backword
    case crossword

    var displayName: String {
        switch self {
        case .backword:
            return "Backword"
        case .crossword:
            return "Crossword"
        }
    }

    var adPlacement: AdService.UserDefaultsKey {
        switch self {
        case .backword:
            return .backwordOpen
        case .crossword:
            return .dailyPuzzleOpen
        }
    }
}

#Preview("Default") {
    let puzzleService = PuzzleService()
    let storeService = StoreService()
    return HomeView(viewModel: HomeViewModel(puzzleService: puzzleService, storeService: storeService))
        .environmentObject(puzzleService)
        .environmentObject(StatsService())
        .environmentObject(storeService)
        .environmentObject(AdService())
        .environmentObject(OverallRatingService())
}

#if DEBUG
#Preview("Completed Puzzle") {
    let vm = HomeViewModel(puzzleService: PuzzleService(), storeService: StoreService())
    vm.debugSetSampleCompleted()
    return HomeView(viewModel: vm)
        .environmentObject(PuzzleService())
        .environmentObject(StatsService())
        .environmentObject(StoreService())
        .environmentObject(AdService())
        .environmentObject(OverallRatingService())
}
#endif
