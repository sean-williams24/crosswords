import SwiftUI

struct AnagramStatsView: View {
    private var progress: [AnagramProgress] { AnagramProgress.loadAll() }
    private var solved: [AnagramProgress] { progress.filter { $0.outcome == .solved } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                stat("Played", value: progress.count)
                stat("Solved", value: solved.count)
                stat("Best time", value: solved.compactMap(\.elapsedSecondsAtCompletion).min()?.formattedTimeHHMMSS ?? "—")
                stat("Daily points", value: solved.reduce(0) { $0 + $1.releaseDateScore })
                Spacer()
            }
            .padding(AppLayout.screenPadding)
            .background(Color.appBackground)
            .navigationTitle("Anagram stats")
        }
    }

    private func stat(_ title: String, value: Int) -> some View {
        stat(title, value: String(value))
    }

    private func stat(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(AppFont.body())
            Spacer()
            Text(value).font(AppFont.header(22))
        }
        .foregroundStyle(Color.anagramInk)
        .padding(16)
        .background(Color.anagramSurface)
    }
}
