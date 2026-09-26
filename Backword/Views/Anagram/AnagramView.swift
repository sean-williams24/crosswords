import SwiftUI

struct AnagramView: View {
    @EnvironmentObject private var adService: AdService
    @EnvironmentObject private var storeService: StoreService
    @EnvironmentObject private var ratingService: OverallRatingService
    @EnvironmentObject private var accountService: AccountService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var viewModel: AnagramViewModel
    private let showsFirstUseTip: Bool
    @State private var showingInstructions = false
    @State private var showingHintConfirmation = false
    @State private var showingFallback = false
    @State private var showingGiveUp = false
    @State private var showInfoTip = false
    @State private var showingStats = false
    @State private var showingCompletionStats = false
    @State private var hasPresentedCompletion = false
    @State private var shouldPopAfterCompletionSheet = false

    init(puzzle: AnagramPuzzle) {
        _viewModel = StateObject(wrappedValue: AnagramViewModel(puzzle: puzzle))
        showsFirstUseTip = true
    }

    fileprivate init(viewModel: AnagramViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        showsFirstUseTip = false
    }

    private var appLayout: AppLayout {
        AppLayout(sizeClass: sizeClass)
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if UserDefaults.standard.string(forKey: "Anagram.firstReleaseDate") != nil {
                        GameScoreProgressBarView(rating: ratingService.rating, category: .anagram)
                            .accessibilityLabel("Anagram rolling rating")
                    }
                    if let progress = viewModel.progress {
                        activeGame(progress)
                    } else {
                        instructions
                    }
                    #if DEBUG
                    if viewModel.puzzle.date == "review" {
                        Button("Reset review puzzle") {
                            AnagramProgress.delete(date: "review")
                            viewModel.reload()
                            hasPresentedCompletion = false
                        }
                        .font(AppFont.body())
                        .foregroundStyle(Color.anagramOrange)
                    }
                    #endif
                }
                .padding(AppLayout.screenPadding)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            if let progress = viewModel.progress {
                gameplayDock(progress)
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.bottom, AppLayout.anagramBottomDockInset)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .background(Color.appBackground)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Anagram")
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .enableSwipeBack()
        .sheet(
            isPresented: $showingStats,
            onDismiss: {
                if shouldPopAfterCompletionSheet {
                    dismiss()
                }
            }
        ) {
            if showingCompletionStats,
               let progress = viewModel.progress,
               progress.isComplete {
                AnagramStatsView(
                    completion: AnagramCompletion(puzzle: viewModel.puzzle, progress: progress),
                    shouldPop: $shouldPopAfterCompletionSheet
                )
            } else {
                AnagramStatsView()
            }
        }
        .alert("How to play", isPresented: $showingInstructions) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Tap scrambled letters to fill the answer from left to right. Undo takes back your last tile. Restart returns your tiles but keeps the timer and hint. Solve quickly to earn up to five points.")
        }
        .confirmationDialog("Reveal one letter?", isPresented: $showingHintConfirmation) {
            if storeService.isProUser {
                Button("Reveal letter · +30 seconds") { reveal(.timePenalty) }
            } else {
                Button("Watch an ad for a letter") { showRewardedHint() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your placed letters will return to the tray. The revealed letter stays locked and cannot be undone.")
        }
        .confirmationDialog("Ad unavailable", isPresented: $showingFallback) {
            Button("Reveal letter · +30 seconds") { reveal(.timePenalty) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The ad did not grant a hint. You can use the +30-second alternative.")
        }
        .confirmationDialog("Give up?", isPresented: $showingGiveUp) {
            Button("Give up and reveal answer", role: .destructive) {
                viewModel.giveUp()
            }
            Button("Keep playing", role: .cancel) { }
        } message: {
            Text("This ends today's attempt for zero points.")
        }
        .onAppear {
            if showsFirstUseTip && UserDefaults.standard.bool(forKey: "Anagram.firstUseTipShown") == false {
                UserDefaults.standard.set(true, forKey: "Anagram.firstUseTipShown")
                showInfoTip = true
            }
            presentCompletionIfNeeded()
        }
        .onChange(of: viewModel.progress?.outcome) { _, outcome in
            if outcome == nil {
                hasPresentedCompletion = false
            } else {
                presentCompletionIfNeeded()
            }
        }
        .onChange(of: accountService.syncRevision) { _, _ in
            viewModel.reload()
            ratingService.refresh()
        }
    }

    private var navigationBar: some View {
        ZStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(AppFont.body(appLayout.iconGlyphSize))
                        .frame(width: appLayout.iconSize)
                        .foregroundStyle(Color.appTextPrimary)
                        .padding(.vertical, 8)
                }
                .accessibilityLabel("Back")

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showingCompletionStats = false
                        showingStats = true
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .font(AppFont.body(appLayout.iconGlyphSize))
                            .frame(width: appLayout.iconSize)
                            .foregroundStyle(Color.appTextPrimary)
                            .padding(.vertical, 8)
                    }
                    .accessibilityLabel("Anagram stats")

                    Button { showingInstructions = true } label: {
                        Image(systemName: "info.circle")
                            .font(AppFont.body(appLayout.iconGlyphSize))
                            .frame(width: appLayout.iconSize)
                            .foregroundStyle(Color.appTextPrimary)
                            .padding(.vertical, 8)
                    }
                    .accessibilityLabel("How to play Anagram")
                    .popover(isPresented: $showInfoTip, arrowEdge: .top) {
                        Text("Tap here anytime for the rules and scoring.")
                            .font(AppFont.body())
                            .padding()
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 4)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ANAGRAM")
                .font(AppFont.header(34))
                .foregroundStyle(Color.anagramOrange)
            Text(viewModel.puzzle.puzzleNumber == 0 ? "Review puzzle" : "Puzzle #\(viewModel.puzzle.puzzleNumber)")
                .font(AppFont.caption())
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Unscramble the letters.")
                Text("Find the word.")
            }
            .font(AppFont.header(24))
            .foregroundStyle(Color.anagramInk)
            Text("Tap letters to build an answer. Your clock starts when you press Start and keeps running if you leave the game. Solve in under 30 seconds for five points.")
                .font(AppFont.body())
                .foregroundStyle(Color.anagramInk)
            Text("\(viewModel.puzzle.length) letters - one optional hint - no time limit")
                .font(AppFont.caption())
                .foregroundStyle(Color.anagramOrange)
            AnagramActionButton(title: "Start", prominent: true) { viewModel.start() }
        }
        .padding(20)
        .background(Color.anagramSurface)
    }

    private func activeGame(_ progress: AnagramProgress) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack {
                    Label(progress.elapsedSeconds(at: context.date).formattedTimeHHMMSS, systemImage: "timer")
                    Spacer()
                    if progress.penaltySeconds > 0 { Text("+\(progress.penaltySeconds.formattedTimeHHMMSS) hint") }
                }
                .font(AppFont.header(20))
                .foregroundStyle(Color.anagramOrange)
            }
            AnagramLetterGrid(puzzle: viewModel.puzzle, progress: progress, section: .answer)
            if !progress.isComplete,
               progress.displayedAnswer(for: viewModel.puzzle) != nil {
                Text("Not quite. Undo a letter or restart and try again.")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.anagramInk)
            }
        }
    }

    private func gameplayDock(_ progress: AnagramProgress) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            AnagramLetterGrid(puzzle: viewModel.puzzle, progress: progress, section: .tray) { tile in
                viewModel.place(tile)
            }
            controls(progress)
        }
    }

    private func controls(_ progress: AnagramProgress) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                AnagramActionButton(title: "Undo", enabled: viewModel.canUndo) { viewModel.undo() }
                AnagramActionButton(title: "Restart", enabled: viewModel.canRestart) { viewModel.restart() }
                AnagramActionButton(title: "Shuffle", enabled: !progress.isComplete) { viewModel.shuffle() }
            }
            HStack(spacing: 10) {
                AnagramActionButton(title: "Hint", enabled: viewModel.canHint) { showingHintConfirmation = true }
                AnagramActionButton(title: "Give up", enabled: !progress.isComplete) { showingGiveUp = true }
            }
        }
    }

    private func reveal(_ source: AnagramProgress.HintSource) {
        viewModel.revealHint(source: source)
    }

    private func showRewardedHint() {
        adService.showRewardedAd { result in
            switch result {
            case .earnedReward: reveal(.rewardedAd)
            case .dismissedWithoutReward: break
            case .unavailable, .failedToPresent: showingFallback = true
            }
        }
    }

    private func presentCompletionIfNeeded() {
        guard AnagramCompletionSheetPresentation.shouldPresent(
            isComplete: viewModel.progress?.isComplete == true,
            hasPresented: hasPresentedCompletion
        ) else { return }
        hasPresentedCompletion = true
        ratingService.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard viewModel.progress?.isComplete == true else { return }
            showingCompletionStats = true
            showingStats = true
        }
    }
}

#if DEBUG
@MainActor
private enum AnagramPreviewData {
    static let puzzle = AnagramPuzzle(
        id: "00000000-0000-4000-8000-000000000099",
        date: "preview",
        puzzleNumber: 1,
        schemaVersion: 1,
        answer: "TRIANGLE",
        acceptedAnswers: ["INTEGRAL"],
        initialScramble: "RAGTLINE"
    )

    static func inProgress() -> AnagramProgress {
        let now = Date()
        var progress = AnagramProgress(puzzle: puzzle, now: now.addingTimeInterval(-75))
        progress.place(3, in: puzzle, now: now)
        progress.place(0, in: puzzle, now: now)
        return progress
    }

    static func solved() -> AnagramProgress {
        let now = Date()
        var progress = AnagramProgress(puzzle: puzzle, now: now.addingTimeInterval(-85))
        for tile in [3, 0, 5, 1, 6, 2, 4, 7] {
            progress.place(tile, in: puzzle, now: now)
        }
        return progress
    }

    static func view(progress: AnagramProgress? = nil) -> some View {
        NavigationStack {
            AnagramView(viewModel: AnagramViewModel(
                puzzle: puzzle,
                initialProgress: progress,
                persistsChanges: false
            ))
            .environmentObject(AdService())
            .environmentObject(StoreService())
            .environmentObject(OverallRatingService())
            .environmentObject(AccountService())
        }
    }
}

#Preview("Start") {
    AnagramPreviewData.view()
}

#Preview("In Progress") {
    AnagramPreviewData.view(progress: AnagramPreviewData.inProgress())
}

#Preview("Solved") {
    AnagramPreviewData.view(progress: AnagramPreviewData.solved())
}
#endif
