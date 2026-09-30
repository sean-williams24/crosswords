import SwiftUI
import TipKit

struct HomeView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var puzzleService: PuzzleService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @EnvironmentObject var ratingService: OverallRatingService
    @EnvironmentObject var accountService: AccountService
    @ObservedObject private var viewModel: HomeViewModel
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var wotdService = WOTDService()
    @StateObject private var backwordService = BackwordService()
    @StateObject private var anagramService = AnagramService()
    @StateObject private var backwordStatsService = BackwordStatsService()
    @State private var anagramProgressRecords: [AnagramProgress] = []
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
    @State private var showPaywallAfterSettingsDismiss = false
    @State private var showAccount = false
    @State private var showRatingDetailsAfterAccountDismiss = false
    @State private var showRatingDetailsAfterSettingsDismiss = false
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

    private func refreshHomeContent() async {
        await viewModel.refreshIfNeeded()
        await wotdService.refreshIfNeeded()
        await backwordService.refreshIfNeeded()
        await anagramService.refreshIfNeeded()
        await viewModel.prefetchCurrentArchiveMonthIfNeeded()
        backwordStatsService.refresh()
        refreshAnagramCardProgress()
        ratingService.refresh()
        ratingService.recordCurrentPuzzles(
            daily: viewModel.todaysPuzzle,
            weekly: viewModel.weeklyPuzzle
        )
    }

    private func refreshHomeContentAtMidnight() async {
        // Sleep until local midnight then trigger a full refresh, then repeat each day.
        while !Task.isCancelled {
            let rolloverScoringCalendar = ContentReleaseCalendar()
            guard let delay = secondsUntilMidnight(), delay > 0 else { break }
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { break }
            ratingService.recordCurrentPuzzles(
                daily: viewModel.todaysPuzzle,
                weekly: viewModel.weeklyPuzzle,
                releaseCalendar: rolloverScoringCalendar
            )
            await viewModel.loadTodaysPuzzle()
            await wotdService.refreshIfNeeded()
            await backwordService.refreshIfNeeded()
            await anagramService.refreshIfNeeded()
            await viewModel.prefetchCurrentArchiveMonthIfNeeded()
            backwordStatsService.refresh()
            refreshAnagramCardProgress()
            ratingService.refresh()
        }
    }

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        homeLifecycleView
    }

    private var homeNavigationView: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackgroundGradient()

                GeometryReader { viewport in
                    ScrollView {
                        VStack(spacing: 20) {
                            RatingBarView(
                                rating: ratingService.rating,
                                isPro: storeService.isProUser
                            )
                            .padding(.horizontal, appLayout.homeHorizontalPadding)
                            .padding(.bottom, dynamicTypeSize > .accessibility3 ? 16 : 0)

                            gamesGrid
                            adFreeExperienceButton
                            HomeWordOfTheDayView(
                                word: wotdService.todaysWord,
                                showsInlineDetails: HomeWordOfTheDayLayout.showsInlineDetails(
                                    viewportWidth: viewport.size.width,
                                    dynamicTypeSize: dynamicTypeSize
                                )
                            ) {
                                showWOTD = true
                            }
                            .padding(.horizontal, appLayout.homeHorizontalPadding)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                }
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
                navigationDestination(for: destination)
            }
        }
    }

    @ViewBuilder
    private func navigationDestination(for destination: String) -> some View {
        switch destination {
        case "weekly":
            if let puzzle = viewModel.weeklyPuzzle {
                crosswordDestination(puzzle: puzzle)
            }
        case "backword":
            if let word = backwordService.todaysWord {
                BackwordView(word: word)
                    .environmentObject(storeService)
                    .environmentObject(adService)
                    .environmentObject(ratingService)
            }
        case "anagram":
            if let puzzle = anagramService.todaysPuzzle {
                anagramDestination(puzzle: puzzle)
            }
        case "puzzle":
            if let puzzle = viewModel.todaysPuzzle {
                crosswordDestination(puzzle: puzzle)
            }
        default:
            EmptyView()
        }
    }

    private func crosswordDestination(puzzle: Puzzle) -> some View {
        PuzzleView(viewModel: GameViewModel(puzzle: puzzle))
            .environmentObject(statsService)
            .environmentObject(storeService)
            .environmentObject(adService)
            .environmentObject(ratingService)
    }

    private func anagramDestination(puzzle: AnagramPuzzle) -> some View {
        AnagramView(puzzle: puzzle)
            .environmentObject(storeService)
            .environmentObject(adService)
            .environmentObject(ratingService)
    }

    private var primaryPresentationView: some View {
        homeNavigationView
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
    }

    private var settingsPresentationView: some View {
        primaryPresentationView
            #if DEBUG
            .sheet(isPresented: $showDebugSettings, onDismiss: {
                refreshAnagramCardProgress()
                ratingService.refresh()
            }) {
                DebugSettingsView(homeViewModel: viewModel)
                    .environmentObject(storeService)
                    .environmentObject(backwordService)
                    .environmentObject(anagramService)
                    .environmentObject(adService)
                    .environmentObject(wotdService)
                    .environmentObject(accountService)
            }
            #endif
            .sheet(isPresented: $showSettings, onDismiss: presentDeferredSheetAfterSettingsDismissIfNeeded) {
                SettingsView(
                    onSubscribe: {
                        showPaywallAfterSettingsDismiss = true
                        showSettings = false
                    },
                    onShowRatingDetails: {
                        showRatingDetailsAfterSettingsDismiss = true
                        showSettings = false
                    }
                )
                .environmentObject(storeService)
            }
            .sheet(isPresented: $showAccount, onDismiss: presentRatingDetailsAfterAccountDismissIfNeeded) {
                AccountSheet {
                    showRatingDetailsAfterAccountDismiss = true
                    showAccount = false
                }
                    .environmentObject(accountService)
            }
    }

    private var homePresentationView: some View {
        settingsPresentationView
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
    }

    private var homeTaskView: some View {
        homePresentationView
            .task {
                await refreshHomeContent()
            }
            .task {
                await refreshHomeContentAtMidnight()
            }
            .onAppear(perform: handleHomeAppear)
    }

    private var homeTipObservationView: some View {
        homeTaskView
            .onChange(of: launchSplashDidComplete) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: adService.adStartupDidComplete) { _, _ in
                updateSettingsTipReadiness()
            }
            .onChange(of: adService.isPresentingFullScreenAd) { _, _ in
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
    }

    private var homeStateObservationView: some View {
        homeTipObservationView
            .onChange(of: navigationPath) { oldPath, newPath in
                handleNavigationPathChange(oldPath: oldPath, newPath: newPath)
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
    }

    private var homeAccountObservationView: some View {
        homeStateObservationView
            .onChange(of: accountService.userID) { _, _ in
                refreshProgressAfterAccountChange()
            }
            .onChange(of: accountService.syncRevision) { _, _ in
                refreshProgressAfterAccountChange()
            }
    }

    private var homeLifecycleView: some View {
        homeAccountObservationView
            .alert(
                AccountDeletionPresentation.title,
                isPresented: accountDeletionNoticeBinding
            ) {
                Button("Continue", role: .cancel) {
                    accountService.dismissAccountDeletionNotice()
                }
            } message: {
                Text(accountService.accountDeletionNotice ?? "")
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

    private var accountDeletionNoticeBinding: Binding<Bool> {
        Binding(
            get: { accountService.accountDeletionNotice != nil },
            set: { isPresented in
                if !isPresented {
                    accountService.dismissAccountDeletionNotice()
                }
            }
        )
    }

    private func handleHomeAppear() {
        logoVisible = false
        proLogoVisible = false
        updateSettingsTipReadiness()
        animateLogo()
        Task {
            await viewModel.refreshIfNeeded()
            await viewModel.prefetchCurrentArchiveMonthIfNeeded()
            backwordStatsService.refresh()
            refreshAnagramCardProgress()
        }
    }

    private func handleNavigationPathChange(oldPath: [String], newPath: [String]) {
        if !oldPath.isEmpty, newPath.isEmpty, hasOpenedDailyGameThisSession {
            didReturnFromDailyGame = true
            backwordStatsService.refresh()
        }
        refreshAnagramCardProgress()
        updateSettingsTipReadiness()
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
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
                await anagramService.refreshIfNeeded()
                await viewModel.prefetchCurrentArchiveMonthIfNeeded()
                await accountService.refreshAccountData()
                refreshAnagramCardProgress()
            }
        }
    }

    private func refreshProgressAfterAccountChange() {
        statsService.refreshForActiveProgress()
        backwordStatsService.refresh()
        refreshAnagramCardProgress()
        ratingService.refresh()
    }

    private var gamesGrid: some View {
        LazyVGrid(columns: HomeGamesLayout.columns(for: sizeClass), spacing: HomeGamesLayout.spacing) {
            ForEach(HomeGamesLayout.games, id: \.self) { game in
                gameCard(for: game)
            }
        }
        .padding(.horizontal, appLayout.homeHorizontalPadding)
    }

    @ViewBuilder
    private func gameCard(for game: HomeGamesLayout.Game) -> some View {
        switch game {
        case .backword:
            backwordCard
        case .quickCrossword:
            dailyCrosswordCard
        case .anagram:
            anagramCard
        case .proCrossword:
            WeeklyCrosswordCard(viewModel: viewModel, isProUser: storeService.isProUser)
                .environmentObject(storeService)
        }
    }

    @ViewBuilder
    private var anagramCard: some View {
        if let puzzle = anagramService.todaysPuzzle {
            AnagramCard(
                puzzle: puzzle,
                summary: AnagramHomeCardSummary(
                    progress: anagramProgressRecords.first { $0.date == puzzle.date && $0.puzzleID == puzzle.id },
                    history: anagramProgressRecords
                )
            ) { navigationPath.append("anagram") }
        } else {
            AnagramPlaceholderCard(
                isLoading: anagramService.isLoading || !anagramService.hasAttemptedLoad
            ) {
                Task { await anagramService.refreshIfNeeded() }
            }
        }
    }

    @ViewBuilder
    private var navigationBar: some View {
        ZStack(alignment: .center) {
            VStack(spacing: navBarVStackSpacing) {
                BackwordLogo()
                    .offset(x: logoVisible ? 0 : 120)
                    .opacity(logoVisible ? 1 : 0)
                #if DEBUG
                    .onTapGesture(count: HomeNavigationDebugGesturePolicy.tapCount) {
                        showDebugSettings = true
                    }
                #endif
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
                Button {
                    openAccountDestination()
                } label: {
                    Image(systemName: accountService.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                        .font(AppFont.body(AppLayout.homeNavigationIconGlyphSize))
                        .foregroundColor(.appTextSecondary)
                }
                .accessibilityLabel(accountService.isSignedIn ? "Account" : "Sign in")
                .padding(.leading, AppLayout.screenPadding)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(AppFont.body(AppLayout.homeNavigationIconGlyphSize))
                        .foregroundColor(.appTextSecondary)
                }
                .popoverTip(SettingsTip())
                .padding(.trailing, AppLayout.screenPadding)
            }
        }
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

    private func refreshAnagramCardProgress() {
        anagramProgressRecords = AnagramProgress.loadAll()
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
            || showAccount
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

    private func presentDeferredSheetAfterSettingsDismissIfNeeded() {
        if showRatingDetailsAfterSettingsDismiss {
            showRatingDetailsAfterSettingsDismiss = false
            showRatingDetails = true
            return
        }

        guard showPaywallAfterSettingsDismiss else { return }
        showPaywallAfterSettingsDismiss = false
        showPaywall = true
    }

    private func presentRatingDetailsAfterAccountDismissIfNeeded() {
        guard showRatingDetailsAfterAccountDismiss else { return }
        showRatingDetailsAfterAccountDismiss = false
        showRatingDetails = true
    }

    private func openAccountDestination() {
        switch AccountPresentationDestination.destination(isSignedIn: accountService.isSignedIn) {
        case .signIn:
            showAccount = true
        case .ratingDetails:
            showRatingDetails = true
        }
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

    // MARK: - Helpers

    private func secondsUntilMidnight() -> TimeInterval? {
        ContentReleaseCalendar().secondsUntilDailyRefresh()
    }
}

enum HomeGamesLayout {
    enum Game: CaseIterable, Hashable, Sendable {
        case backword
        case quickCrossword
        case anagram
        case proCrossword
    }

    static let games = Game.allCases
    static let spacing: CGFloat = 20

    static func columns(for sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        let count = sizeClass == .regular ? 2 : 1
        return Array(repeating: GridItem(.flexible(minimum: 0), spacing: spacing), count: count)
    }
}

enum HomeNavigationDebugGesturePolicy {
    static let tapCount = 3
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

#if DEBUG
@MainActor
struct HomeViewPreviewContainer: View {
    @StateObject private var puzzleService: PuzzleService
    @StateObject private var statsService: StatsService
    @StateObject private var storeService: StoreService
    @StateObject private var adService: AdService
    @StateObject private var ratingService: OverallRatingService
    @StateObject private var accountService: AccountService
    @StateObject private var viewModel: HomeViewModel

    init(completedPuzzle: Bool = false) {
        let puzzleService = PuzzleService()
        let storeService = StoreService()
        let viewModel = HomeViewModel(
            puzzleService: puzzleService,
            storeService: storeService
        )
        if completedPuzzle {
            viewModel.debugSetSampleCompleted()
        }

        _puzzleService = StateObject(wrappedValue: puzzleService)
        _statsService = StateObject(wrappedValue: StatsService())
        _storeService = StateObject(wrappedValue: storeService)
        _adService = StateObject(wrappedValue: AdService())
        _ratingService = StateObject(wrappedValue: OverallRatingService())
        _accountService = StateObject(wrappedValue: AccountService())
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        HomeView(viewModel: viewModel)
            .environmentObject(puzzleService)
            .environmentObject(statsService)
            .environmentObject(storeService)
            .environmentObject(adService)
            .environmentObject(ratingService)
            .environmentObject(accountService)
    }
}

#Preview("Default") {
    HomeViewPreviewContainer()
}

#Preview("Completed Puzzle") {
    HomeViewPreviewContainer(completedPuzzle: true)
}
#endif
