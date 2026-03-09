import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject var puzzleService: PuzzleService
    @EnvironmentObject var statsService: StatsService

    @State private var entries: [ArchiveEntry] = []
    @State private var isLoading = true
    @State private var selectedPuzzle: Puzzle?
    @State private var loadingPuzzleId: String?
    @State private var showPuzzle = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.appAccent)
                } else if entries.isEmpty {
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
                            ForEach(entries) { entry in
                                archiveRow(entry)
                            }
                        }
                        .padding(.horizontal, AppLayout.screenPadding)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
            .navigationDestination(isPresented: $showPuzzle) {
                if let puzzle = selectedPuzzle {
                    PuzzleView(viewModel: GameViewModel(puzzle: puzzle))
                        .environmentObject(statsService)
                }
            }
            .task {
                await loadArchive()
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func archiveRow(_ entry: ArchiveEntry) -> some View {
        Button {
            Task { await loadAndNavigate(entry) }
        } label: {
            HStack(spacing: 16) {
                // Puzzle number
                Text("#\(entry.puzzleNumber)")
                    .font(AppFont.statNumber())
                    .foregroundColor(.appTextPrimary)
                    .frame(width: 56, alignment: .leading)

                // Date
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

                // Status indicator
                if loadingPuzzleId == entry.id {
                    ProgressView()
                        .tint(.appAccent)
                        .scaleEffect(0.8)
                } else {
                    statusBadge(for: entry)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusBadge(for entry: ArchiveEntry) -> some View {
        let status = puzzleStatus(for: entry)
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 11))
            Text(status.label)
                .font(AppFont.clueLabel(11))
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.color.opacity(0.12))
        .cornerRadius(12)
    }

    // MARK: - Status

    private enum PuzzleStatus {
        case completed, inProgress, notStarted

        var icon: String {
            switch self {
            case .completed: return "checkmark.circle.fill"
            case .inProgress: return "pencil.circle"
            case .notStarted: return "circle"
            }
        }

        var label: String {
            switch self {
            case .completed: return "Done"
            case .inProgress: return "In Progress"
            case .notStarted: return "New"
            }
        }

        var color: Color {
            switch self {
            case .completed: return .appCorrect
            case .inProgress: return .appAccent
            case .notStarted: return .appTextSecondary
            }
        }
    }

    private func puzzleStatus(for entry: ArchiveEntry) -> PuzzleStatus {
        guard let progress = UserProgress.load(puzzleId: entry.id) else {
            return .notStarted
        }
        return progress.isComplete ? .completed : .inProgress
    }

    // MARK: - Actions

    private func loadArchive() async {
        defer { isLoading = false }
        entries = (try? await puzzleService.fetchArchive()) ?? []
    }

    private func loadAndNavigate(_ entry: ArchiveEntry) async {
        loadingPuzzleId = entry.id
        defer { loadingPuzzleId = nil }

        if let puzzle = try? await puzzleService.fetchPuzzle(forDate: entry.date) {
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
