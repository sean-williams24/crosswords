import SwiftUI

struct HomeView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var puzzleService: PuzzleService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var wotdService = WOTDService()

    @State private var showStats = false
    @State private var showArchive = false
    @State private var showPaywall = false
    @State private var showWOTD = false
    @State private var navigateToPuzzle = false

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
                        Text(storeService.isProUser ? "CROSSWORDS PRO" : "CROSSWORDS")
                            .font(AppFont.header(36))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.appTextPrimary)
                            .tracking(4)

//                        Text(formattedDate)
//                            .font(AppFont.caption())
//                            .foregroundColor(.appTextSecondary)
//                            .tracking(1)
                    }
                    .padding()

                    // Streak badge
                    if statsService.stats.liveCurrentStreak > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(statsService.stats.liveCurrentStreak)-day streak")
                                .font(AppFont.clueLabel(13))
                                .foregroundColor(.appTextPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appSurface)
                        .cornerRadius(20)
                    } else if statsService.stats.totalCompleted > 0 {
                        HStack(spacing: 6) {
                            Text("💔")
                                .font(.system(size: 14))
                            Text("No streak — solve today's puzzle!")
                                .font(AppFont.clueLabel(13))
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appSurface)
                        .cornerRadius(20)
                    }

                    Spacer()

                    // Word of the Day
                    if let word = wotdService.todaysWord {
                        Button {
                            showWOTD = true
                        } label: {
                            wotdCard(word: word)
                        }
                        .buttonStyle(.plain)
                    }

                    // Today's puzzle card
                    if viewModel.todaysPuzzle != nil {
                        NavigationLink(value: "puzzle") {
                            todayCard(puzzle: viewModel.todaysPuzzle!)
                        }
                        .buttonStyle(.plain)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .tint(.appAccent)
                    }

                    Spacer()

                    // Bottom buttons
                    VStack(spacing: 12) {
                        Button {
                            showStats = true
                        } label: {
                            Label("Stats", systemImage: "chart.bar")
                                .font(AppFont.body())
                                .foregroundColor(.appTextPrimary)
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
                            .font(AppFont.body())
                            .foregroundColor(.appTextPrimary)
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
            .navigationDestination(for: String.self) { _ in
                if let puzzle = viewModel.todaysPuzzle {
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
                await viewModel.loadTodaysPuzzle()
            }
        }
    }

    // MARK: - Today Card

    @ViewBuilder
    private func todayCard(puzzle: Puzzle) -> some View {
        VStack(spacing: 12) {
            Text("DAILY CROSSWORD")
                .font(AppFont.clueLabel(11))
                .foregroundColor(.appTextSecondary)
                .tracking(3)

//            Text("#\(puzzle.puzzleNumber)")
//                .font(AppFont.statNumber())
//                .foregroundColor(.appTextPrimary)

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

            Image(systemName: "play.fill")
                .font(.system(size: 11))
                .foregroundColor(.appAccent)
                .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface)
        .cornerRadius(AppLayout.cardCornerRadius)
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
