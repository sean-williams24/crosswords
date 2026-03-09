import SwiftUI

struct HomeView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var puzzleService: PuzzleService
    @StateObject private var viewModel: HomeViewModel

    @State private var showStats = false
    @State private var showArchive = false
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
                        Text("CROSSWORDS")
                            .font(AppFont.header(36))
                            .foregroundColor(.appTextPrimary)
                            .tracking(4)

//                        Text(formattedDate)
//                            .font(AppFont.caption())
//                            .foregroundColor(.appTextSecondary)
//                            .tracking(1)
                    }

                    // Streak badge
                    if statsService.stats.currentStreak > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(statsService.stats.currentStreak)-day streak")
                                .font(AppFont.clueLabel(13))
                                .foregroundColor(.appTextPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.appSurface)
                        .cornerRadius(20)
                    }

                    Spacer()

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
                            showArchive = true
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                                .font(AppFont.body())
                                .foregroundColor(.appTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
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
                }
            }
            .sheet(isPresented: $showStats) {
                StatsView()
                    .environmentObject(statsService)
            }
            .sheet(isPresented: $showArchive) {
                ArchiveView()
                    .environmentObject(puzzleService)
                    .environmentObject(statsService)
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
            Text("DAILY PUZZLE")
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

    // MARK: - Helpers

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt.string(from: Date()).uppercased()
    }

}
