import SwiftUI
import TipKit

struct HomeView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var puzzleService: PuzzleService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @EnvironmentObject var ratingService: OverallRatingService
    @EnvironmentObject var accountService: AccountService
    @EnvironmentObject private var dailyIntervlsOnboarding: DailyIntervlsOnboardingViewModel
    @ObservedObject private var viewModel: HomeViewModel
    private let offersAnalyticsConsentBanner: Bool
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var wotdService = WOTDService()
    @StateObject private var backwordService = BackwordService()
    @StateObject private var midwordService = MidwordService()
    @State private var midwordProgress: MidwordProgress?
    @StateObject private var anagramService = AnagramService()
    @StateObject private var backwordStatsService = BackwordStatsService()
    @StateObject private var dailyChallenge = HomeDailyChallengeViewModel()
    @State private var anagramProgressRecords: [AnagramProgress] = []
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.launchSplashDidComplete) private var launchSplashDidComplete
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var homeHasAppeared = false
    @ScaledMetric var proLogoFrame: CGFloat = AppLayout.homeProLogoHeight
    @ScaledMetric var navBarVStackSpacing: CGFloat = AppLayout.homeProLogoSpacing
    @ScaledMetric var navBarProLogoOffset: CGFloat = AppLayout.homeProLogoTrailingOffset
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
    @State private var dailyIntervlsGuideMode: DailyIntervlsGuideView.Mode?
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

    private var homeIsAvailable: Bool {
        homeHasAppeared && launchSplashDidComplete && scenePhase == .active
            && !adService.isPresentingFullScreenAd && !homeHasActivePresentation
            && accountService.accountDeletionNotice == nil
    }

    private var canPresentDailyCelebration: Bool {
        homeIsAvailable && dailyIntervlsOnboarding.pendingStep == nil && !viewModel.crosswordsFetchDidFail
    }

    private var dailyIntervlsHomeStep: DailyIntervlsGuideStep? {
        dailyIntervlsOnboarding.homeStep(isReady: homeIsAvailable && !dailyChallenge.isCelebrating)
    }

    private var blocksSettingsTip: Bool {
        dailyIntervlsOnboarding.pendingStep != nil
            || dailyIntervlsGuideMode != nil
    }

    private var nextAnagramHomeProgressTick: Date? {
        guard homeHasAppeared, navigationPath.isEmpty, scenePhase == .active else { return nil }
        return dailyChallenge.snapshot.nextAnagramProgressTick
    }

    private func refreshDailyChallenge(source: HomeDailyChallengeViewModel.RefreshSource = .local) {
        dailyChallenge.refresh(accountID: accountService.userID?.uuidString, dailyPuzzle: viewModel.todaysPuzzle, source: source)
    }

    private func refreshHomeContent() async {
        refreshDailyChallenge()
        await viewModel.refreshIfNeeded()
        await wotdService.refreshIfNeeded()
        await backwordService.refreshIfNeeded()
        await midwordService.refreshIfNeeded()
        await anagramService.refreshIfNeeded()
        await viewModel.prefetchCurrentArchiveMonthIfNeeded()
        backwordStatsService.refresh()
        refreshMidwordProgress()
        refreshAnagramCardProgress()
        ratingService.refresh()
        ratingService.recordCurrentPuzzles(
            daily: viewModel.todaysPuzzle,
            weekly: viewModel.weeklyPuzzle
        )
        refreshDailyChallenge()
    }

    private func refreshHomeContentAtMidnight() async {
        // Sleep until local midnight then trigger a full refresh, then repeat each day.
        while !Task.isCancelled {
            let rolloverScoringCalendar = ContentReleaseCalendar()
            guard let delay = secondsUntilMidnight(), delay > 0 else { break }
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { break }
            refreshDailyChallenge()
            ratingService.recordCurrentPuzzles(
                daily: viewModel.todaysPuzzle,
                weekly: viewModel.weeklyPuzzle,
                releaseCalendar: rolloverScoringCalendar
            )
            await viewModel.loadTodaysPuzzle()
            await wotdService.refreshIfNeeded()
            await backwordService.refreshIfNeeded()
            await midwordService.refreshIfNeeded()
            await anagramService.refreshIfNeeded()
            await viewModel.prefetchCurrentArchiveMonthIfNeeded()
            backwordStatsService.refresh()
            refreshMidwordProgress()
            refreshAnagramCardProgress()
            ratingService.refresh()
            refreshDailyChallenge()
        }
    }

    init(viewModel: HomeViewModel, offersAnalyticsConsentBanner: Bool = false) {
        self.viewModel = viewModel
        self.offersAnalyticsConsentBanner = offersAnalyticsConsentBanner
    }

    var body: some View {
        homeLifecycleView
            .modifier(AnalyticsConsentBannerPresentation(
                isAvailable: offersAnalyticsConsentBanner && dailyIntervlsOnboarding.pendingStep == nil
                    && dailyIntervlsGuideMode?.isOnboarding != true
            ))
            .allowsHitTesting(dailyIntervlsGuideMode == nil)
            .accessibilityHidden(dailyIntervlsGuideMode != nil)
            .blur(radius: dailyIntervlsGuideMode == nil ? 0 : AppLayout.dailyIntervlsGuideScreenBlurRadius)
            .overlay {
                if let dailyIntervlsGuideMode {
                    DailyIntervlsGuideView(
                        mode: dailyIntervlsGuideMode,
                        isPro: storeService.isProUser,
                        acknowledgeGameplay: { dailyIntervlsOnboarding.acknowledgeGameplay() },
                        finishOnboarding: { dailyIntervlsOnboarding.finishOnboarding() },
                        dismiss: { self.dailyIntervlsGuideMode = nil }
                    )
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: dailyIntervlsGuideMode != nil)
    }

    private var homeNavigationView: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackgroundGradient()

                HomeDashboardView(
                    usesTwoColumns: HomeGamesLayout.usesTwoColumns(for: sizeClass),
                    scrollToTopTrigger: dailyChallenge.isCelebrating ? dailyChallenge.celebrationID : 0
                ) {
                    homeContent(isExpanded: true)
                } compact: {
                    homeContent(isExpanded: false)
                }
            }
            .onAppear(perform: handleHomeAppear)
            .onDisappear {
                homeHasAppeared = false
                dailyChallenge.setHomeAvailable(false)
            }
            .task(id: canPresentDailyCelebration) {
                // A pop updates the path before Home finishes appearing. Keep
                // feedback queued until its content is visible and settled.
                dailyChallenge.setHomeAvailable(false)
                guard canPresentDailyCelebration else { return }
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                guard !Task.isCancelled else { return }
                dailyChallenge.returnFromGame(
                    accountID: accountService.userID?.uuidString, dailyPuzzle: viewModel.todaysPuzzle
                )
                dailyChallenge.setHomeAvailable(true)
            }
            .task(id: nextAnagramHomeProgressTick) {
                guard let tick = nextAnagramHomeProgressTick else { return }
                do {
                    try await Task.sleep(for: .seconds(max(0, tick.timeIntervalSinceNow + 0.05)))
                } catch { return }
                guard !Task.isCancelled else { return }
                refreshDailyChallenge()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                navigationBar
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                archiveFooterBar
            }
            .allowsHitTesting(!dailyChallenge.isCelebrating && dailyIntervlsOnboarding.pendingStep == nil)
            .accessibilityHidden(dailyChallenge.isCelebrating || dailyIntervlsOnboarding.pendingStep != nil)
            .overlay {
                if dailyChallenge.isCelebrating, let result = dailyChallenge.celebrationSnapshot {
                    HomeDailyChallengeCelebration(snapshot: result, dismiss: {
                        dailyChallenge.dismissCelebration()
                    }, openArchive: {
                        dailyChallenge.dismissCelebration()
                        openArchive()
                    })
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: dailyChallenge.isCelebrating)
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
        case "midword":
            if let puzzle = midwordService.todaysPuzzle {
                MidwordView(puzzle: puzzle)
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
                refreshMidwordProgress()
                refreshAnagramCardProgress()
                ratingService.refresh()
                refreshDailyChallenge(source: .restored)
            }) {
                DebugSettingsView(
                    homeViewModel: viewModel,
                    canReplayDailyCelebration: dailyChallenge.snapshot.isComplete,
                    replayDailyCelebration: { dailyChallenge.replayCelebration() },
                    previewDailyCelebration: { dailyChallenge.previewCelebration() },
                    onDailyGameReset: { date in
                        dailyChallenge.resetCelebrationForDebug(
                            date: date, accountID: accountService.userID?.uuidString,
                            dailyPuzzle: viewModel.todaysPuzzle
                        )
                    }
                )
                    .environmentObject(storeService)
                    .environmentObject(backwordService)
                    .environmentObject(anagramService)
                    .environmentObject(midwordService)
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
    }

    private var homeTipObservationView: some View {
        homeTaskView
            .onChange(of: dailyIntervlsHomeStep, initial: true) { _, step in
                if let step {
                    presentDailyIntervlsGuide(.onboarding(step))
                }
            }
            .onChange(of: blocksSettingsTip) { _, _ in
                updateSettingsTipReadiness()
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
            .onChange(of: showArchive) { _, _ in
                updateSettingsTipReadiness()
                refreshDailyChallenge()
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
            .onChange(of: canPresentDailyCelebration) { _, available in
                if !available { dailyChallenge.setHomeAvailable(false) }
            }
            .onChange(of: navigationPath) { oldPath, newPath in
                handleNavigationPathChange(oldPath: oldPath, newPath: newPath)
            }
            .onChange(of: viewModel.todaysPuzzle?.id) { _, _ in
                refreshDailyChallenge()
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
            .alert("There was a problem loading the games, please check your network.", isPresented: gameLoadAlertBinding) {
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
            get: { accountService.accountDeletionNotice != nil && dailyIntervlsGuideMode == nil },
            set: { isPresented in
                if !isPresented {
                    accountService.dismissAccountDeletionNotice()
                }
            }
        )
    }

    private var gameLoadAlertBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.crosswordsFetchDidFail && dailyIntervlsOnboarding.pendingStep == nil
                    && dailyIntervlsGuideMode == nil && accountService.accountDeletionNotice == nil
            },
            set: { viewModel.crosswordsFetchDidFail = $0 }
        )
    }

    private func handleHomeAppear() {
        homeHasAppeared = true
        refreshDailyChallenge()
        logoVisible = false
        proLogoVisible = false
        updateSettingsTipReadiness()
        animateLogo()
        Task {
            await viewModel.refreshIfNeeded()
            await viewModel.prefetchCurrentArchiveMonthIfNeeded()
            backwordStatsService.refresh()
            refreshMidwordProgress()
            refreshAnagramCardProgress()
            refreshDailyChallenge()
        }
    }

    private func handleNavigationPathChange(oldPath: [String], newPath: [String]) {
        if !oldPath.isEmpty, newPath.isEmpty {
            viewModel.refreshProgressFromDisk()
            refreshDailyChallenge()
        }
        if !oldPath.isEmpty, newPath.isEmpty, hasOpenedDailyGameThisSession {
            didReturnFromDailyGame = true
            backwordStatsService.refresh()
        }
        refreshMidwordProgress()
        refreshAnagramCardProgress()
        updateSettingsTipReadiness()
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        updateSettingsTipReadiness()
        if newPhase == .background || newPhase == .inactive {
            logoVisible = false
            proLogoVisible = false
        } else if newPhase == .active {
            refreshDailyChallenge()
            animateLogo()

            guard !adService.isPresentingFullScreenAd else { return }

            Task {
                await storeService.updateSubscriptionStatus(source: "scene_active")
                await viewModel.refreshIfNeeded()
                await wotdService.refreshIfNeeded()
                await backwordService.refreshIfNeeded()
                await midwordService.refreshIfNeeded()
                await anagramService.refreshIfNeeded()
                await viewModel.prefetchCurrentArchiveMonthIfNeeded()
                await accountService.refreshAccountData()
                refreshMidwordProgress()
                refreshAnagramCardProgress()
                refreshDailyChallenge()
            }
        }
    }

    private func refreshProgressAfterAccountChange() {
        viewModel.refreshProgressFromDisk()
        statsService.refreshForActiveProgress()
        backwordStatsService.refresh()
        refreshMidwordProgress()
        refreshAnagramCardProgress()
        ratingService.refresh()
        refreshDailyChallenge(source: .restored)
    }

    private func homeContent(isExpanded: Bool) -> some View {
        VStack(spacing: HomeGamesLayout.spacing) {
            RatingBarView(
                rating: ratingService.rating, isPro: storeService.isProUser,
                dailyChallenge: dailyChallenge.snapshot,
                dailyCelebrationID: dailyChallenge.isCelebrating ? dailyChallenge.celebrationID : 0,
                onOpenDetails: { showRatingDetails = true }
            )
                .padding(.horizontal, appLayout.homeHorizontalPadding)
                .padding(.bottom, dynamicTypeSize > .accessibility3 ? 16 : 0)

            if !isExpanded {
                wordOfTheDay(showsInlineDetails: false)
            }

            HomeGamesView {
                twoColumnGamesGrid
            } stacked: {
                gamesGrid
            }

            if isExpanded {
                wordOfTheDay(showsInlineDetails: true)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, HomeGamesLayout.scrollBottomPadding)
    }

    private func wordOfTheDay(showsInlineDetails: Bool) -> some View {
        HomeWordOfTheDayView(word: wotdService.todaysWord, showsInlineDetails: showsInlineDetails) {
            showWOTD = true
        }
        .padding(.horizontal, appLayout.homeHorizontalPadding)
    }

    private var twoColumnGamesGrid: some View {
        HomeGameCardsGrid(spacing: HomeGamesLayout.spacing) {
            backwordCard
            dailyCrosswordCard
            anagramCard
            midwordCard
            gameCard(for: .proCrossword)
            HomeArchiveCard(isProUser: storeService.isProUser, openArchive: openArchive)
        }
        .padding(.horizontal, appLayout.homeHorizontalPadding)
    }

    private var gamesGrid: some View {
        HomeGameCardsGrid(columns: 1, spacing: HomeGamesLayout.spacing) {
            ForEach(HomeGamesLayout.gamesBeforeArchiveButton, id: \.self) { game in
                gameCard(for: game)
            }
            adFreeExperienceButton
                .layoutValue(key: HomeGameCardsGridLayout.IntrinsicHeightKey.self, value: true)
            ForEach(HomeGamesLayout.gamesAfterArchiveButton, id: \.self) { game in
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
        case .midword:
            midwordCard
        case .proCrossword:
            WeeklyCrosswordCard(viewModel: viewModel, isProUser: storeService.isProUser)
                .environmentObject(storeService)
        }
    }

    private var midwordCard: some View {
        MidwordCard(
            puzzle: midwordService.todaysPuzzle,
            progress: midwordProgress,
            isLoading: midwordService.isLoading,
            loadFailed: midwordService.loadFailed,
            currentStreak: midwordService.currentStreak,
            retry: { Task { await midwordService.refreshIfNeeded(force: true) } },
            play: {
                cancelSettingsTipPresentation()
                hasOpenedDailyGameThisSession = true
                navigateToDailyChallenge(.midword, destination: "midword")
            }
        )
        .modifier(HomeDailyChallengeCardHighlight(
            progress: dailyChallenge.snapshot[.midword],
            isCurrentRelease: midwordService.todaysPuzzle?.date == dailyChallenge.snapshot.date
        ))
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
            ) { navigateToDailyChallenge(.anagram, destination: "anagram") }
            .modifier(HomeDailyChallengeCardHighlight(
                progress: dailyChallenge.snapshot[.anagram],
                isCurrentRelease: puzzle.date == dailyChallenge.snapshot.date
            ))
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
            VStack(alignment: .trailing, spacing: navBarVStackSpacing) {
                IntervlsLogo(frame: AppLayout.brandHomeLogoHeight)
                    .offset(x: logoVisible ? 0 : 120)
                    .opacity(logoVisible ? 1 : 0)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
            showArchive: openArchive,
            showStats: {
                showRatingDetails = true
            }
        )
    }

    private func openArchive() {
        if storeService.isProUser {
            showArchive = true
        } else {
            showPaywall = true
        }
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
        .modifier(HomeDailyChallengeCardHighlight(
            progress: dailyChallenge.snapshot[.backword],
            isCurrentRelease: backwordService.todaysWord?.date == dailyChallenge.snapshot.date
        ))
    }

    private func refreshAnagramCardProgress() {
        anagramProgressRecords = AnagramProgress.loadAll()
    }

    private var dailyCrosswordCard: some View {
        DailyCrosswordCard(viewModel: viewModel) {
            openDailyGame(.crossword)
        }
        .modifier(HomeDailyChallengeCardHighlight(
            progress: dailyChallenge.snapshot[.crossword],
            isCurrentRelease: viewModel.todaysPuzzle?.date == dailyChallenge.snapshot.date
        ))
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
        !blocksSettingsTip && SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: launchSplashDidComplete,
            navigationBarDidAppear: navigationBarDidAppear,
            adStartupDidComplete: adService.adStartupDidComplete,
            isPresentingFullScreenAd: adService.isPresentingFullScreenAd,
            isHomeNavigationActive: homeHasActivePresentation,
            didReturnFromDailyGame: didReturnFromDailyGame
        )
    }

    private var homeHasActivePresentation: Bool {
        #if DEBUG
        if showDebugSettings { return true }
        #endif
        return !navigationPath.isEmpty
            || showArchive
            || showPaywall
            || showWOTD
            || showAdExplainer
            || showSettings
            || showAccount
            || showRatingDetails
            || dailyIntervlsGuideMode != nil
    }

    private func presentDailyIntervlsGuide(_ mode: DailyIntervlsGuideView.Mode) {
        cancelSettingsTipPresentation()
        dailyIntervlsGuideMode = mode
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
            isInterstitialEligibleToday: adService.canShowInterstitialToday(for: game.adPlacement),
            preGameInterstitialsEnabled: adService.preGameInterstitialsEnabled
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
        adService.shouldUsePreGameAdGate(
            isProUser: storeService.isProUser,
            hasSeenRequiredOnboarding: game != .backword || settings.hasSeenBackwordOnboarding
        )
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
        navigateToDailyChallenge(.backword, destination: "backword")
    }

    private func refreshMidwordProgress() {
        midwordService.refreshStats()
        midwordProgress = midwordService.todaysPuzzle.flatMap { MidwordProgress.load(date: $0.date) }
    }

    private func navigateToDailyCrossword() {
        cancelSettingsTipPresentation()
        hasOpenedDailyGameThisSession = true
        navigateToDailyChallenge(.crossword, destination: "puzzle")
    }

    private func navigateToDailyChallenge(_ game: DailyChallengeGame, destination: String) {
        dailyChallenge.beginGame(game, accountID: accountService.userID?.uuidString, dailyPuzzle: viewModel.todaysPuzzle)
        navigationPath.append(destination)
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
        case midword
        case proCrossword
    }

    static let games = Game.allCases
    static let gamesBeforeArchiveButton = Array(games.prefix { $0 != .anagram })
    static let gamesAfterArchiveButton = Array(games.drop { $0 != .anagram })
    static let spacing: CGFloat = 20
    // The safe-area inset already reserves the tab bar, including its top padding.
    static let scrollBottomPadding = spacing - AppLayout.homeTabBarTopPadding

    static func usesTwoColumns(for sizeClass: UserInterfaceSizeClass?) -> Bool {
        sizeClass == .regular
    }

    static func columns(for sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        let count = usesTwoColumns(for: sizeClass) ? 2 : 1
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
    @StateObject private var dailyIntervlsOnboarding = DailyIntervlsOnboardingViewModel.preview()

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
            .environmentObject(dailyIntervlsOnboarding)
    }
}

#Preview("Default") {
    HomeViewPreviewContainer()
}

#Preview("Completed Puzzle") {
    HomeViewPreviewContainer(completedPuzzle: true)
}
#endif
