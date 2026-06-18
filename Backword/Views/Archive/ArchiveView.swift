import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @StateObject private var viewModel = ArchiveViewModel(
        dataSource: ArchiveDataSource(puzzleService: PuzzleService())
    )

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundGradient()
                archiveContent

                VStack {
                    Spacer()
                    archiveTabToggle
                }
            }
            .navigationTitle(viewModel.currentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.showPuzzle) {
                if let puzzle = viewModel.selectedPuzzle {
                    PuzzleView(viewModel: GameViewModel(puzzle: puzzle))
                        .environmentObject(statsService)
                        .environmentObject(storeService)
                        .environmentObject(adService)
                }
            }
            .task {
                await viewModel.loadInitialArchive()
            }
        }
    }

    @ViewBuilder
    private var archiveContent: some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(.appAccent)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        currentMonthSection
                        earlierMonthsSection
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 112)
                }
                .onChange(of: viewModel.expandedScrollToken(for: viewModel.activeType)) { _, token in
                    guard token != nil else { return }
                    let type = viewModel.activeType
                    Task {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        scrollMonthGridToTop(proxy, type: type)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var currentMonthSection: some View {
        if viewModel.currentContentIsEmpty(for: viewModel.activeType) {
            emptyState
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else {
            Text(viewModel.currentMonthDisplayName.uppercased())
                .font(AppFont.clueLabel(11))
                .foregroundColor(.appTextSecondary)
                .tracking(1)
                .padding(.horizontal, 4)

            archiveRows(for: viewModel.activeType, content: currentContent)
        }
    }

    @ViewBuilder
    private var earlierMonthsSection: some View {
        let type = viewModel.activeType
        let months = viewModel.earlierMonths(for: type)

        Group {
            if !months.isEmpty {
                Text("EARLIER MONTHS")
                    .font(AppFont.clueLabel(11))
                    .foregroundColor(.appTextSecondary)
                    .tracking(1)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                    .id(earlierMonthsHeaderID(for: type))

                ArchiveMonthGrid(
                    months: months,
                    type: type,
                    expandedMonth: viewModel.expandedMonth(for: type),
                    loadingMonths: viewModel.loadingMonths,
                    unavailableMonths: viewModel.unavailableMonths
                ) { month in
                    Task {
                        await viewModel.expandOrCollapse(month, for: type)
                    }
                }

                expandedMonthSection(for: type)
            }
        }
    }

    @ViewBuilder
    private func expandedMonthSection(for type: ArchiveGameType) -> some View {
        if let month = viewModel.expandedMonth(for: type),
           let content = viewModel.expandedContent(for: type),
           !content.isEmpty(for: type) {
            Text(month.displayName.uppercased())
                .font(AppFont.clueLabel(11))
                .foregroundColor(.appTextSecondary)
                .tracking(1)
                .padding(.horizontal, 4)
                .padding(.top, 6)

            archiveRows(for: type, content: content)
        }
    }

    @ViewBuilder
    private func archiveRows(for type: ArchiveGameType, content: ArchiveMonthContent) -> some View {
        switch type {
        case .backword:
            ForEach(content.backwordWords) { word in
                BackwordArchiveRow(word: word)
            }
        case .daily:
            ForEach(content.dailyPuzzles) { puzzle in
                ArchivePuzzleRow(puzzle: puzzle, isWeekly: false) {
                    viewModel.openPuzzle(puzzle)
                }
            }
        case .weekly:
            ForEach(content.weeklyPuzzles) { puzzle in
                ArchivePuzzleRow(puzzle: puzzle, isWeekly: true) {
                    viewModel.openPuzzle(puzzle)
                }
            }
        }
    }

    private var currentContent: ArchiveMonthContent {
        switch viewModel.activeType {
        case .backword:
            return ArchiveMonthContent(backwordWords: viewModel.currentBackwordWords)
        case .daily:
            return ArchiveMonthContent(dailyPuzzles: viewModel.currentDailyPuzzles)
        case .weekly:
            return ArchiveMonthContent(weeklyPuzzles: viewModel.currentWeeklyPuzzles)
        }
    }

    private func earlierMonthsHeaderID(for type: ArchiveGameType) -> String {
        "archive-earlier-months-header-\(type.rawValue)"
    }

    private func scrollMonthGridToTop(_ proxy: ScrollViewProxy, type: ArchiveGameType) {
        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(earlierMonthsHeaderID(for: type), anchor: .top)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.appTextSecondary)
            Text(viewModel.selectedTab == .backword ? "No Backword history yet" : "No puzzles yet")
                .font(AppFont.body())
                .foregroundColor(.appTextSecondary)
        }
    }

    private var bottomBlur: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(.thickMaterial)
                .frame(height: 150)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.9), location: 0.55),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }

    private var archiveTabToggle: some View {
        ArchiveTabBarView(
            tabs: viewModel.tabs,
            selectedTab: viewModel.selectedTab
        ) { tab in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedTab = tab
            }
        }
    }
}

#Preview {
    ArchiveView()
        .environmentObject(StatsService())
        .environmentObject(StoreService())
        .environmentObject(AdService())
}
