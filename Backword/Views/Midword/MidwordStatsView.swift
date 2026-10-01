import SwiftUI

struct MidwordStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var ratingService: OverallRatingService
    @EnvironmentObject private var storeService: StoreService
    let puzzle: MidwordPuzzle
    let progress: MidwordProgress
    let showsCompletion: Bool

    private var completed: [MidwordProgress] {
        MidwordProgress.loadAll().filter { item in
            guard let finished = item.completedAt else { return false }
            return item.date >= OverallRating.midwordLaunchDate
                && ContentReleaseCalendar(now: finished).dailyDateString == item.date
        }
    }

    private var currentStreak: Int {
        let wins = Set(completed.filter(\.isWon).map(\.date))
        let today = ContentReleaseCalendar().dailyDateString
        if completed.contains(where: { $0.date == today && !$0.isWon }) { return 0 }
        let start = wins.contains(today) ? 0 : 1
        var count = 0
        var offset = start
        while offset <= wins.count {
            guard let date = ContentReleaseCalendar().dailyDateString(offsetByDays: -offset),
                  wins.contains(date) else { break }
            count += 1
            offset += 1
        }
        return count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if showsCompletion {
                        Text(progress.isWon ? "Solved!" : "Finished")
                            .font(AppFont.header(38))
                            .foregroundColor(progress.isWon ? .midwordAccent : .appGaveUp)
                        Text(progress.isWon ? "In \(progress.guesses.count) guesses" : "The answer was")
                            .font(AppFont.body())
                        MidwordCompletionWordView(word: puzzle.answer, failed: progress.isFailed)
                        Text("\(puzzle.firstCompound)  ·  \(puzzle.secondCompound)")
                            .font(AppFont.body())
                            .multilineTextAlignment(.center)
                        Text("\(progress.releaseDateScore) points")
                            .font(AppFont.header(24))
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let remaining = max(0, Int(ContentReleaseCalendar(now: context.date).secondsUntilDailyRefresh() ?? 0))
                            Text("NEXT MIDWORD IN  \(remaining / 3600)h \((remaining % 3600) / 60)m \(remaining % 60)s")
                                .font(AppFont.caption())
                        }
                        ShareLink(item: "Midword #\(puzzle.puzzleNumber) · \(progress.releaseDateScore)/5") {
                            Label("Share result", systemImage: "square.and.arrow.up")
                                .font(AppFont.body())
                        }
                    }
                    RatingBarView(rating: ratingService.rating, isPro: storeService.isProUser, category: .midword)
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 16) {
                            stat("PLAYED", value: completed.count)
                            stat("WON", value: completed.filter(\.isWon).count)
                            stat("STREAK", value: currentStreak)
                        }
                    } else {
                        HStack {
                            stat("PLAYED", value: completed.count)
                            stat("WON", value: completed.filter(\.isWon).count)
                            stat("STREAK", value: currentStreak)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Guess distribution").font(AppFont.header(20))
                        ForEach(1...5, id: \.self) { count in
                            HStack {
                                Text("\(count)")
                                GeometryReader { geometry in
                                    let wins = completed.filter { $0.isWon && $0.guesses.count == count }.count
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.midwordAccent)
                                        .frame(width: max(3, geometry.size.width * CGFloat(wins) / CGFloat(max(1, completed.count))), height: 20)
                                }
                                .frame(height: 20)
                            }
                            .font(AppFont.body())
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Last 14 days").font(AppFont.header(20))
                        ForEach(0..<14, id: \.self) { offset in
                            if let date = ContentReleaseCalendar().dailyDateString(offsetByDays: -offset),
                               date >= OverallRating.midwordLaunchDate {
                                let item = MidwordProgress.load(date: date)
                                if dynamicTypeSize.isAccessibilitySize {
                                    VStack(alignment: .leading) {
                                        Text(date)
                                        Text(historyLabel(item))
                                    }
                                    .font(AppFont.caption())
                                } else {
                                    HStack {
                                        Text(date)
                                        Spacer()
                                        Text(historyLabel(item))
                                    }
                                    .font(AppFont.caption())
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(.appTextPrimary)
                .padding(AppLayout.screenPadding)
            }
            .background(Color.appBackground)
            .navigationTitle("Midword Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
        }
    }

    private func stat(_ title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(AppFont.statNumber(36))
            Text(title).font(AppFont.caption())
        }
        .frame(maxWidth: .infinity)
    }

    private func historyLabel(_ item: MidwordProgress?) -> String {
        guard let item else { return "Not played" }
        if item.isWon { return "\(item.guesses.count) guesses · \(item.releaseDateScore) pts" }
        if item.isFailed { return "Failed" }
        return "In progress · \(item.guesses.count) guesses"
    }
}
