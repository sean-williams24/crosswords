import SwiftUI

struct AnagramView: View {
    private enum PendingSheet: Equatable {
        case stats
        case instructions
        case completion
    }

    @EnvironmentObject private var adService: AdService
    @EnvironmentObject private var storeService: StoreService
    @EnvironmentObject private var ratingService: OverallRatingService
    @EnvironmentObject private var accountService: AccountService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var viewModel: AnagramViewModel
    private let showsFirstUseTip: Bool
    @State private var showingInstructions = false
    @State private var showingHintBanner = false
    @State private var hintBannerMode: AnagramHintBannerMode = .watchAd
    @State private var isRewardedAdRequestInFlight = false
    @State private var showingPaywall = false
    @State private var showingGiveUp = false
    @State private var showInfoTip = false
    @State private var isTipDismissing = false
    @State private var pendingSheet: PendingSheet?
    @State private var isViewVisible = false
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
            if showingHintBanner {
                AnagramHintBanner(
                    mode: hintBannerMode,
                    narrowsAnswers: viewModel.puzzle.hintNarrowsAnswers,
                    isBusy: isRewardedAdRequestInFlight,
                    onPrimaryAction: useHintBannerPrimaryAction,
                    onGoAdFree: { showingPaywall = true },
                    onClose: closeHintBanner
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
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
        .sheet(isPresented: $showingInstructions) {
            instructionsSheet
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
                .environmentObject(storeService)
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
            isViewVisible = true
            showInfoTip = AnagramFirstUseTipPresentation.shouldShow(
                showsFirstUseTip: showsFirstUseTip,
                hasSeenTip: UserDefaults.standard.bool(forKey: "Anagram.firstUseTipShown"),
                isComplete: viewModel.progress?.isComplete == true
            )
            presentCompletionIfNeeded()
        }
        .onDisappear {
            isViewVisible = false
            isTipDismissing = false
            pendingSheet = nil
        }
        .onChange(of: showInfoTip) { wasShown, isShown in
            guard wasShown && !isShown else { return }
            isTipDismissing = true
            if pendingSheet != .completion {
                UserDefaults.standard.set(true, forKey: "Anagram.firstUseTipShown")
            }
            // SwiftUI clears the binding before the popover dismissal animation finishes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTipDismissing = false
                guard isViewVisible, !showInfoTip, let sheet = pendingSheet else { return }
                pendingSheet = nil
                present(sheet)
            }
        }
        .onChange(of: viewModel.progress?.outcome) { _, outcome in
            if outcome == nil {
                hasPresentedCompletion = false
                if pendingSheet == .completion { pendingSheet = nil }
            } else {
                closeHintBanner()
                request(.completion)
            }
        }
        .onChange(of: viewModel.canHint) { _, canHint in
            if !canHint { closeHintBanner() }
        }
        .onChange(of: storeService.isProUser) { _, isProUser in
            if showingHintBanner { hintBannerMode = AnagramHintBannerMode(isProUser: isProUser) }
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
                        request(.stats)
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .font(AppFont.body(appLayout.iconGlyphSize))
                            .frame(width: appLayout.iconSize)
                            .foregroundStyle(Color.appTextPrimary)
                            .padding(.vertical, 8)
                    }
                    .accessibilityLabel("Anagram stats")

                    Button {
                        request(.instructions)
                    } label: {
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

    private var instructionsSheet: some View {
        NavigationStack {
            AnagramInstructionsContentView()
                .navigationTitle("How to Play")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingInstructions = false } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.anagramOrange)
                        }
                        .accessibilityLabel("Close How to Play")
                    }
                }
                .toolbarBackground(Color.appBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.fraction(0.85)])
        .presentationDragIndicator(.visible)
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
                AnagramActionButton(title: "Hint", enabled: viewModel.canHint) {
                    hintBannerMode = AnagramHintBannerMode(isProUser: storeService.isProUser)
                    withAnimation { showingHintBanner = true }
                }
                AnagramActionButton(title: "Give up", enabled: !progress.isComplete) { showingGiveUp = true }
            }
        }
    }

    private func reveal(_ source: AnagramProgress.HintSource) {
        viewModel.revealHint(source: source)
    }

    private func request(_ sheet: PendingSheet) {
        if showInfoTip {
            pendingSheet = sheet
            isTipDismissing = true
            showInfoTip = false
        } else if isTipDismissing {
            pendingSheet = sheet
        } else {
            present(sheet)
        }
    }

    private func present(_ sheet: PendingSheet) {
        switch sheet {
        case .stats:
            showingCompletionStats = false
            showingStats = true
        case .instructions:
            showingInstructions = true
        case .completion:
            presentCompletionIfNeeded()
        }
    }

    private func closeHintBanner() {
        withAnimation { showingHintBanner = false }
    }

    private func useHintBannerPrimaryAction() {
        guard viewModel.canHint, !isRewardedAdRequestInFlight else { return }
        if hintBannerMode != .watchAd {
            closeHintBanner()
            reveal(.timePenalty)
            return
        }

        isRewardedAdRequestInFlight = true
        adService.showRewardedAd { result in
            isRewardedAdRequestInFlight = false
            switch AnagramHintAdAction(result: result) {
            case .reveal:
                closeHintBanner()
                reveal(.rewardedAd)
            case .offerTimePenalty:
                hintBannerMode = .adUnavailable
            case .close:
                closeHintBanner()
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
