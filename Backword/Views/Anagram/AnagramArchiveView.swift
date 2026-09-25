import SwiftUI

struct AnagramArchiveView: View {
    @EnvironmentObject private var storeService: StoreService
    @EnvironmentObject private var adService: AdService
    @EnvironmentObject private var ratingService: OverallRatingService
    @StateObject private var service = AnagramService()
    @State private var selectedMonth = ArchiveMonth.current()
    @State private var puzzles: [AnagramPuzzle] = []
    @State private var isLoading = false
    @State private var showingPaywall = false

    private var months: [ArchiveMonth] {
        guard let first = UserDefaults.standard.string(forKey: "Anagram.firstReleaseDate"),
              let firstMonth = ArchiveMonth.from(dateString: first) else { return [] }
        let current = ArchiveMonth.current()
        var result = [ArchiveMonth]()
        var year = current.year
        var month = current.month
        while year > firstMonth.year || (year == firstMonth.year && month >= firstMonth.month) {
            result.append(ArchiveMonth(year: year, month: month))
            month -= 1
            if month == 0 { year -= 1; month = 12 }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if !storeService.isProUser {
                    VStack(spacing: 16) {
                        Text("Anagram archive is included with Pro")
                            .font(AppFont.header(22))
                        AnagramActionButton(title: "Explore Pro", prominent: true) { showingPaywall = true }
                    }
                    .padding(AppLayout.screenPadding)
                } else {
                    archiveContent
                }
            }
            .navigationTitle("Anagram archive")
            .sheet(isPresented: $showingPaywall) {
                PaywallView().environmentObject(storeService)
            }
            .task(id: storeService.isProUser) { await load(selectedMonth) }
        }
    }

    private var archiveContent: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(months) { month in
                        Button(month.shortDisplayName) {
                            Task { await load(month) }
                        }
                        .font(AppFont.caption())
                        .foregroundStyle(selectedMonth == month ? Color.anagramOnOrange : Color.anagramOrange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(selectedMonth == month ? Color.anagramOrange : Color.anagramSurface)
                    }
                }
                .padding(AppLayout.screenPadding)
            }
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List(puzzles) { puzzle in
                    NavigationLink {
                        AnagramView(puzzle: puzzle)
                            .environmentObject(adService)
                            .environmentObject(storeService)
                            .environmentObject(ratingService)
                    } label: {
                        HStack {
                            Text("Anagram #\(puzzle.puzzleNumber)")
                                .font(AppFont.body())
                            Spacer()
                            Text(puzzle.date)
                                .font(AppFont.caption())
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }
                .overlay {
                    if puzzles.isEmpty {
                        Text("No published Anagram puzzles this month")
                            .font(AppFont.body())
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
        }
    }

    private func load(_ month: ArchiveMonth) async {
        guard storeService.isProUser else { return }
        selectedMonth = month
        isLoading = true
        puzzles = await service.fetchArchive(for: month)
        isLoading = false
    }
}
