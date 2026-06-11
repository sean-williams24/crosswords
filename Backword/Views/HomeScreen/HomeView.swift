import SwiftUI
import TipKit

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
    #if DEBUG
    @State private var showDebugSettings = false
    #endif

    private var appLayout: AppLayout {
        AppLayout(sizeClass: sizeClass)
    }

    init(viewModel: HomeViewModel? = nil) {
        // Can't use @EnvironmentObject in init, so create with a temporary service
        // The real service is injected via .onAppear
        _viewModel = StateObject(wrappedValue: viewModel ?? HomeViewModel(puzzleService: PuzzleService(), storeService: StoreService()))
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
            .task {
                await viewModel.refreshIfNeeded()
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
                    await viewModel.refreshIfNeeded()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background || newPhase == .inactive {
                    logoVisible = false
                    proLogoVisible = false
                } else if newPhase == .active {
                    animateLogo()
                    
                    Task {
                        await viewModel.refreshIfNeeded()
                        await wotdService.refreshIfNeeded()
                        await backwordService.refreshIfNeeded()
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
                if isAfterLocalMidnight(at: context.date) {
                    dateView(for: utcResetCountdown(at: context.date))
                } else {
                    dateView(for: DateFormatting().formattedDate)
                }
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
                        .shadow(color: .primary, radius: 2, x: 0, y: 1)
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
                if isBeforeWeeklyResetUTC(at: context.date) {
                    dateView(for: weeklyResetCountdown(at: context.date))
                } else {
                    dateView(for: weeklyRefreshLabel(at: context.date))
                }
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
    }

    @ViewBuilder
    private var archiveFooterBar: some View {
        VStack(spacing: 0) {
            HStack {
                archiveButton
                statsButton
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.top, 8)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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

    private var statsButton: some View {
        Button {
            showRatingDetails = true
        } label: {
            Label("Stats", systemImage: "brain.head.profile")
                .font(AppFont.clueLabel(14))
                .foregroundColor(.appTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
    }

    private var archiveButton: some View {
        Button {
            if storeService.isProUser {
                showArchive = true
            } else {
                showPaywall = true
            }
        } label: {
            Label("Archive", systemImage: storeService.isProUser ? "archivebox" : "lock.fill")
                .font(AppFont.clueLabel(16))
                .foregroundColor(.appTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
    }

    private var backwordCard: some View {
        BackwordCard(
            service: backwordService,
            progress: backwordService.todaysWord.flatMap {
                BackwordProgress.load(date: $0.date)
            }
        ) {
            navigationPath.append("backword")
        }
        .environmentObject(adService)
    }

    private var dailyCrosswordCard: some View {
        DailyCrosswordCard(viewModel: viewModel) {
            navigationPath.append("puzzle")
        }
        .environmentObject(adService)
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

    /// Returns true when the local date has ticked past midnight but UTC midnight hasn't fired yet.
    private func isAfterLocalMidnight(at date: Date = Date()) -> Bool {
        let localFmt = DateFormatter()
        localFmt.dateFormat = "yyyy-MM-dd"
        let utcFmt = DateFormatter()
        utcFmt.dateFormat = "yyyy-MM-dd"
        utcFmt.timeZone = TimeZone(identifier: "UTC")!
        return localFmt.string(from: date) != utcFmt.string(from: date)
    }

    /// Returns a string like "RESETS IN 1:05" counting down to the next UTC midnight.
    private func utcResetCountdown(at date: Date = Date()) -> String {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        guard let utcMidnight = utcCal.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return "RESETS SOON" }
        let totalMinutes = max(0, Int(utcMidnight.timeIntervalSince(date) / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0
            ? String(format: "Resets in %d:%02d", hours, minutes)
            : String(format: "%d minutes remaining", minutes)
    }

    private func secondsUntilMidnight() -> TimeInterval? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let midnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return nil }
        return midnight.timeIntervalSinceNow
    }

    /// Returns true when local day is Sunday but UTC midnight hasn't flipped to Sunday yet.
    private func isBeforeWeeklyResetUTC(at date: Date = Date()) -> Bool {
        let localCal = Calendar(identifier: .gregorian)
        guard localCal.component(.weekday, from: date) == 1 else { return false }
        return isAfterLocalMidnight(at: date)
    }

    /// Returns a label like "Refreshes Sundays at 1 AM" showing the local time of the weekly UTC reset.
    private func weeklyRefreshLabel(at date: Date = Date()) -> String {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(hour: 0, minute: 0, second: 0, weekday: 1)
        guard let nextSunMidnight = utcCal.nextDate(
            after: date,
            matching: components,
            matchingPolicy: .nextTime
        ) else { return "Refreshes Sundays" }
        let fmt = DateFormatter()
        fmt.dateFormat = "h a"
        return "Refreshes Sundays at \(fmt.string(from: nextSunMidnight))"
    }

    /// Returns a string like "New puzzle in 1:05" counting down to the next Sunday UTC midnight.
    private func weeklyResetCountdown(at date: Date = Date()) -> String {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(hour: 0, minute: 0, second: 0, weekday: 1)
        guard let nextSunMidnight = utcCal.nextDate(
            after: date,
            matching: components,
            matchingPolicy: .nextTime
        ) else { return "New puzzle soon" }
        let totalMinutes = max(0, Int(nextSunMidnight.timeIntervalSince(date) / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0
            ? String(format: "New puzzle in %d:%02d", hours, minutes)
            : String(format: "%d minutes remaining", minutes)
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
