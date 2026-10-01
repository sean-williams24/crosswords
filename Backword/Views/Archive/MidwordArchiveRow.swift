import SwiftUI

struct MidwordArchiveRow: View {
    let puzzle: MidwordPuzzle
    @EnvironmentObject private var ratingService: OverallRatingService
    @State private var showGame = false
    @State private var progress: MidwordProgress?

    var body: some View {
        Button { showGame = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(puzzle.firstWord)  ·  ?  ·  \(puzzle.secondWord)")
                        .font(AppFont.header(18))
                    Text("\(puzzle.date)  ·  #\(puzzle.puzzleNumber)")
                        .font(AppFont.caption())
                }
                Spacer()
                Text(status).font(AppFont.caption())
            }
            .foregroundColor(.appTextPrimary)
            .padding(AppLayout.screenPadding)
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: $showGame) {
            MidwordView(puzzle: puzzle).environmentObject(ratingService)
        }
        .onAppear(perform: refresh)
        .onChange(of: showGame) { _, shown in if !shown { refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: .midwordProgressDidChange)) { _ in refresh() }
    }

    private var status: String {
        guard let progress else { return "New" }
        if progress.isWon { return "Solved" }
        if progress.isFailed { return "Failed" }
        return "In progress"
    }

    private func refresh() { progress = MidwordProgress.load(date: puzzle.date) }
}
