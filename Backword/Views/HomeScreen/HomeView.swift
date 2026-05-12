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
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @State private var showArchive = false
    @State private var showPaywall = false
    @State private var showWOTD = false
    @State private var showSettings = false
    @State private var navigateToPuzzle = false
    @State private var navigateToWeekly = false
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        RatingBarView(
                            rating: ratingService.rating,
                            isPro: storeService.isProUser
                        )
                        .padding(.horizontal, AppLayout.screenPadding)
                        .padding(.bottom, dynamicTypeSize > .accessibility3 ? 16 : 0)

                        wotd
                        dailyGamesView
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
                        .onAppear {
                            if !storeService.isProUser {
                                adService.showInterstitialOnce(for: .backwordOpen)
                            }
                        }
                } else if let puzzle = viewModel.todaysPuzzle {
                    PuzzleView(viewModel: GameViewModel(puzzle: puzzle))
                        .environmentObject(statsService)
                        .environmentObject(storeService)
                        .environmentObject(adService)
                        .environmentObject(ratingService)
                        .onAppear {
                            if !storeService.isProUser {
                                adService.showInterstitialOnce(for: .dailyPuzzleOpen)
                            }
                        }
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
                    .environmentObject(adService)
                    .environmentObject(wotdService)
            }
            #endif
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(storeService)
            }
            .sheet(isPresented: $showWOTD, onDismiss: {
                if !storeService.isProUser {
                    adService.showInterstitialOnce(for: .wotdDismiss)
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
    private var weeklyGamesView: some View {
        VStack(spacing: 0) {
            Text("Weekly Games")
                .font(AppFont.header(16))
                .padding(.top, isIpad ? 6 : 0)
                .padding(.bottom, 6)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                if isBeforeWeeklyResetUTC(at: context.date) {
                    Text(weeklyResetCountdown(at: context.date))
                        .font(AppFont.caption())
                        .foregroundColor(Color.appTextSecondary)
                        .tracking(1)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)
                } else {
                    Text(weeklyRefreshLabel(at: context.date))
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                        .tracking(1)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)
                }
            }
            .padding(.bottom, isIpad ? 16 : 0)

            WeeklyCrosswordCard(viewModel: viewModel, isProUser: storeService.isProUser)
                .environmentObject(storeService)
        }
    }

    private var dailyGamesView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 1)
            Text("Daily Games")
                .font(AppFont.header(16))
                .padding(.top, 26)
                .padding(.bottom, 6)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                if isAfterLocalMidnight(at: context.date) {
                    Text(utcResetCountdown(at: context.date))
                        .font(AppFont.caption())
                        .foregroundColor(Color.appTextSecondary)
                        .tracking(1)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 26)
                } else {
                    Text(DateFormatting().formattedDate)
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                        .tracking(1)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 26)
                }
            }

            if sizeClass == .regular {
                HStack(spacing: 45) {
                    backwordCard
                        .shadow(color: .primary, radius: .pi, x: 0.2, y: 0.2)
                    DailyCrosswordCard(viewModel: viewModel)
                }
                .padding(.horizontal, 45)
                .padding(.bottom, 60)
            } else {
                Group {
                    backwordCard
                        .shadow(color: .primary, radius: .pi, x: 0.2, y: 0.2)
                    DailyCrosswordCard(viewModel: viewModel)
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.bottom, 20)
            }

            Rectangle()
                .frame(height: 1)
                .shadow(color: .primary, radius: .pi, x: 0.2, y: 0.6)
        }
//        .background {
//            LinearGradient(
//                colors: [Color.appGridLine.opacity(0.55), Color.appBackground],
//                startPoint: .topLeading,
//                endPoint: .bottomTrailing
//            )
//        }
    }

    @ViewBuilder
    private var navigationBar: some View {
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

    @ViewBuilder
    private var archiveFooterBar: some View {
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

    @ViewBuilder
    private var backwordCard: some View {
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
        .padding(.horizontal, isIpad ? 45 : AppLayout.screenPadding)
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
