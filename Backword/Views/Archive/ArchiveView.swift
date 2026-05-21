import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject var puzzleService: PuzzleService
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @State private var entries: [ArchiveEntry] = []
    @State private var weeklyEntries: [ArchiveEntry] = []
    @State private var backwordWords: [BackwordWord] = []
    @State private var isLoading = true
    @State private var selectedTab: ArchiveTab = .backword
    @State private var selectedPuzzle: Puzzle?
    @State private var loadingPuzzleId: String?
    @State private var showPuzzle = false
    @State private var selectedBackwordWord: BackwordWord?
    @State private var showBackword = false

    private let backwordService = BackwordService()

    private enum ArchiveTab: String, CaseIterable {
        case backword = "Backword"
        case daily = "Daily\n Crossword"
        case weekly = "Pro\n Crossword"
    }

    private var activeEntries: [ArchiveEntry] {
        selectedTab == .daily ? entries : weeklyEntries
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.appAccent)
                } else if selectedTab == .backword {
                    if backwordWords.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(.appTextSecondary)
                            Text("No Backword history yet")
                                .font(AppFont.body())
                                .foregroundColor(.appTextSecondary)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(backwordWords) { word in
                                    BackwordArchiveRow(word: word)
                                }
                            }
                            .padding(.horizontal, AppLayout.screenPadding)
                            .padding(.top, 16)
                            .padding(.bottom, 96)
                        }
                    }
                } else if activeEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.appTextSecondary)
                        Text("No puzzles yet")
                            .font(AppFont.body())
                            .foregroundColor(.appTextSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(activeEntries) { entry in
                                archiveRow(entry)
                            }
                        }
                        .padding(.horizontal, AppLayout.screenPadding)
                        .padding(.top, 16)
                        .padding(.bottom, 96)
                    }
                }

                // Gradient blur backdrop
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(.thickMaterial)
                        .frame(height: 220)
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

                VStack {
                    Spacer()
                    archiveTabToggle
                }
            }
            .navigationTitle(" \(selectedTab.rawValue) Archive")
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
            .navigationDestination(isPresented: $showPuzzle) {
                if let puzzle = selectedPuzzle {
                    PuzzleView(viewModel: GameViewModel(puzzle: puzzle))
                        .environmentObject(statsService)
                        .environmentObject(storeService)
                        .environmentObject(adService)
                }
            }
            .task {
                await loadArchive()
            }
        }
    }

    // MARK: - Tab Toggle

    @ViewBuilder
    private var archiveTabToggle: some View {
        HStack(spacing: 0) {
            archiveTabToggleContent
        }
    }

    private var archiveTabToggleContent: some View {
        ForEach(ArchiveTab.allCases, id: \.self) { tab in
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = tab
                }
            } label: {
                Text(tab.rawValue)
                    .font(AppFont.clueLabel(selectedTab == tab ? 15 : 13))
                    .minimumScaleFactor(0.6)
                    .foregroundColor(selectedTab == tab ? .appTextPrimary : .appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
            }
            .buttonStyle(.plain)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    // MARK: - Row

    @ViewBuilder
    private func archiveRow(_ entry: ArchiveEntry) -> some View {
        let fraction = progressFraction(for: entry)
        Button {
            Task { await loadAndNavigate(entry) }
        } label: {
            VStack(spacing: 0) {
                ViewThatFits {
                    HStack(spacing: 16) {
                        archiveRowContent(entry)
                    }
                    VStack(alignment: .leading) {
                        archiveRowContent(entry)
                    }
                }
                .frame(minHeight: 50)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                // Progress bar
                if fraction > 0 {
                    GeometryReader { geo in
                        Capsule()
                            .fill(progressColor(for: fraction))
                            .frame(width: geo.size.width * fraction, height: 3)
                            .animation(.easeOut(duration: 0.6), value: fraction)
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func archiveRowContent(_ entry: ArchiveEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formattedDate(entry.date))
                .font(AppFont.body())
                .foregroundColor(.appTextPrimary)

            if isToday(entry.date) {
                Text("TODAY")
                    .font(AppFont.clueLabel(10))
                    .foregroundColor(.appAccent)
                    .tracking(1)
            }
        }

        Spacer()

        if loadingPuzzleId == entry.id {
            ProgressView()
                .tint(.appAccent)
                .scaleEffect(0.8)
        } else {
            StatusLabelView(status: .status(for: entry))
        }
    }

    private func progressFraction(for entry: ArchiveEntry) -> CGFloat {
        guard let progress = UserProgress.load(puzzleId: entry.id) else { return 0 }
        if progress.isComplete { return 1.0 }
        let filled = progress.entries.flatMap { $0 }.compactMap { $0 }.count
        guard filled > 0 else { return 0 }
        // Use cached puzzle to count fillable (non-black) cells
        let cache = CacheService()
        if let puzzle = cache.loadPuzzle(for: entry.date) {
            let fillable = puzzle.cells.flatMap { $0 }.filter { !$0.isBlack }.count
            guard fillable > 0 else { return 0 }
            return min(CGFloat(filled) / CGFloat(fillable), 1.0)
        }
        // Fallback: estimate ~65% of grid is fillable
        let total = progress.entries.flatMap { $0 }.count
        guard total > 0 else { return 0 }
        let estimatedFillable = Double(total) * 0.65
        return min(CGFloat(Double(filled) / estimatedFillable), 1.0)
    }

    private func progressColor(for fraction: CGFloat) -> Color {
        if fraction >= 1.0 { return .appCorrect }
        // Blue → Green lerp
        let blue = 1.0 - fraction
        let green = fraction
        return Color(red: 0.15, green: 0.35 + green * 0.5, blue: 0.4 + blue * 0.45)
    }

    // MARK: - Actions

    private func loadArchive() async {
        defer { isLoading = false }
        async let daily = try? await puzzleService.fetchArchive()
        async let weekly = try? await puzzleService.fetchWeeklyArchive()
        async let backword = try? await backwordService.fetchArchive()
        entries = await daily ?? []
        weeklyEntries = await weekly ?? []
        backwordWords = await backword ?? []
    }

    private func loadAndNavigate(_ entry: ArchiveEntry) async {
        loadingPuzzleId = entry.id
        defer { loadingPuzzleId = nil }

        let puzzle: Puzzle?
        if selectedTab == .weekly {
            puzzle = try? await puzzleService.fetchWeeklyPuzzle(forDate: entry.date)
        } else {
            puzzle = try? await puzzleService.fetchPuzzle(forDate: entry.date)
        }

        if let puzzle {
            selectedPuzzle = puzzle
            showPuzzle = true
        }
    }

    // MARK: - Formatting

    private func formattedDate(_ dateString: String) -> String {
        let inputFmt = DateFormatter()
        inputFmt.dateFormat = "yyyy-MM-dd"
        guard let date = inputFmt.date(from: dateString) else { return dateString }

        let outputFmt = DateFormatter()
        outputFmt.dateFormat = "EEEE, MMM d"
        return outputFmt.string(from: date)
    }

    private func isToday(_ dateString: String) -> Bool {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return dateString == fmt.string(from: Date())
    }
}

#Preview {
    ArchiveView()
        .environmentObject(PuzzleService())
        .environmentObject(StatsService())
        .environmentObject(StoreService())
        .environmentObject(AdService())
}
