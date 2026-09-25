import SwiftUI

struct AnagramStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ratingService: OverallRatingService
    @EnvironmentObject private var storeService: StoreService
    @State private var progressRecords: [AnagramProgress] = []

    private let previewHistory: AnagramStatsHistory?

    init(previewHistory: AnagramStatsHistory? = nil) {
        self.previewHistory = previewHistory
    }

    private var history: AnagramStatsHistory {
        previewHistory ?? AnagramStatsHistory.make(
            rating: ratingService.rating,
            progressRecords: progressRecords
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RatingBarView(
                    rating: ratingService.rating,
                    isPro: storeService.isProUser,
                    category: .anagram,
                    accentColor: .anagramOrange,
                    trackColor: .anagramSurface
                )
                .padding(.top, 20)
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        StatsView(anagram: history)
                            .padding(.horizontal, AppLayout.screenPadding)
                        AnagramStatsHistoryView(rows: history.rows)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, AppLayout.anagramBottomDockInset)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Anagram Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.anagramOrange)
                    }
                    .accessibilityLabel("Close Anagram stats")
                }
            }
        }
        .onAppear {
            guard previewHistory == nil else { return }
            ratingService.refresh()
            progressRecords = AnagramProgress.loadAll()
        }
    }
}

#Preview {
    AnagramStatsView(previewHistory: AnagramStatsHistory.make(
        rating: OverallRating(), progressRecords: []
    ))
    .environmentObject(OverallRatingService(rating: OverallRating()))
    .environmentObject(StoreService())
}
