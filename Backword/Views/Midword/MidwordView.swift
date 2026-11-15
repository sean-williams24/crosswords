import SwiftUI

struct MidwordSheetPresentation: Equatable {
    var showsStats = false
    var showsInstructions = false
    var showsCompletion = false

    var isPresentingSheet: Bool {
        showsStats || showsInstructions || showsCompletion
    }
}

struct MidwordView: View {
    @StateObject private var viewModel: MidwordViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var ratingService: OverallRatingService
    @State private var sheetPresentation = MidwordSheetPresentation()
    @State private var shouldPopAfterCompletionSheet = false
    @State private var showGiveUpConfirmation = false

    private var appLayout: AppLayout { AppLayout(sizeClass: sizeClass) }

    init(puzzle: MidwordPuzzle) {
        _viewModel = StateObject(wrappedValue: MidwordViewModel(puzzle: puzzle))
    }

    var body: some View {
        GameDynamicTypeContainer {
            VStack(spacing: 0) {
                navBar
                Text("Puzzle #\(viewModel.puzzle.puzzleNumber)")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
                if viewModel.hasStarted || viewModel.isComplete {
                    ScrollView { gameContent }
                } else {
                    MidwordStartView(
                        answerLength: viewModel.puzzle.answer.count,
                        onStart: { viewModel.start() }
                    )
                }
                inputControls
            }
            .coordinateSpace(name: GameStartCoordinateSpace.viewport)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.canSubmit)
        .background(Color.midwordBackground.ignoresSafeArea())
        .blur(radius: sheetPresentation.isPresentingSheet ? AppLayout.sheetBackgroundBlurRadius : 0)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .navigationBarBackButtonHidden()
        .alert("Give up?", isPresented: $showGiveUpConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reveal Answer", role: .destructive) { viewModel.giveUp() }
        } message: {
            Text("This will reveal the answer for zero points.")
        }
        .onAppear { if viewModel.isComplete { sheetPresentation.showsCompletion = true } }
        .onChange(of: viewModel.isComplete) { _, complete in
            if complete {
                ratingService.refresh()
                sheetPresentation.showsCompletion = true
            }
        }
        .sheet(
            isPresented: $sheetPresentation.showsCompletion,
            onDismiss: {
                if shouldPopAfterCompletionSheet { dismiss() }
            }
        ) {
            MidwordStatsView(
                puzzle: viewModel.puzzle,
                progress: viewModel.progress,
                showsCompletion: true,
                shouldPop: $shouldPopAfterCompletionSheet
            )
        }
        .sheet(isPresented: $sheetPresentation.showsStats) {
            MidwordStatsView(puzzle: viewModel.puzzle, progress: viewModel.progress, showsCompletion: false)
        }
        .sheet(isPresented: $sheetPresentation.showsInstructions) {
            NavigationStack {
                MidwordInstructionsView()
                    .navigationTitle("How to Play")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { sheetPresentation.showsInstructions = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.midwordAccent)
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
    }

    private var gameContent: some View {
        VStack(spacing: 24) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(viewModel.isComplete ? viewModel.progress.formattedCompletionTime : MidwordProgress.formatTime(viewModel.progress.elapsedSeconds(at: context.date)))
                    .font(AppFont.header(24))
                    .foregroundStyle(Color.midwordText)
                    .monospacedDigit()
                    .accessibilityLabel("Elapsed time")
            }
            Text(viewModel.gameExplainer)
                .font(AppFont.body())
                .foregroundColor(.midwordText.opacity(0.85))
                .multilineTextAlignment(.center)
            MidwordBoardView(puzzle: viewModel.puzzle, input: viewModel.input, progress: viewModel.progress)
            if let message = viewModel.message {
                Text(message).font(AppFont.body()).foregroundColor(.midwordText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .padding(AppLayout.screenPadding)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.progress.guesses.count)
        .animation(.easeInOut(duration: 0.3), value: viewModel.message != nil)
    }

    @ViewBuilder
    private var inputControls: some View {
        if viewModel.hasStarted || viewModel.isComplete {
            VStack(spacing: 0) {
                GameScoreProgressBarView(rating: ratingService.rating, category: .midword)
                    .padding(.vertical, viewModel.canSubmit ? 5 : 0)
                if viewModel.canSubmit {
                    GameSubmitButton(
                        backgroundColor: .midwordAccent,
                        textColor: .midwordOnAccent
                    ) { viewModel.submitGuess() }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 10)
                    .background(Color.midwordBackground)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                CustomKeyboardView(
                    onKeyTap: { key in
                        if let letter = key.first { viewModel.enterLetter(letter) }
                    },
                    onDelete: { viewModel.deleteLetter() },
                    backgroundColor: .midwordBackground,
                    keyColor: .midwordText.opacity(0.12),
                    specialKeyColor: .midwordAccent,
                    textColor: .midwordText,
                    specialTextColor: .midwordOnAccent
                )
                .disabled(viewModel.isComplete)
            }
        }
    }

    private var navBar: some View {
        ZStack {
            navTitle
            navControls
        }
        .foregroundColor(.midwordText)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 12)
    }

    private var navTitle: some View {
        MidwordLogo()
    }

    private var navControls: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .frame(width: appLayout.iconSize, height: appLayout.iconSize)
            }
            .accessibilityLabel("Back")
            Spacer()
            if viewModel.hasStarted && !viewModel.isComplete {
                GiveUpFlagButton(iconSize: appLayout.iconSize, glyphSize: appLayout.iconGlyphSize) {
                    showGiveUpConfirmation = true
                }
            }
            Button { sheetPresentation.showsStats = true } label: {
                Image(systemName: "brain.head.profile")
                    .frame(width: appLayout.iconSize, height: appLayout.iconSize)
            }
            .accessibilityLabel("Statistics")
            Button { sheetPresentation.showsInstructions = true } label: {
                Image(systemName: "info.circle")
                    .frame(width: appLayout.iconSize, height: appLayout.iconSize)
            }
            .accessibilityLabel("How to play")
        }
        .font(AppFont.body(appLayout.iconGlyphSize))
    }
}

#if DEBUG
private extension MidwordView {
    init(previewViewModel: MidwordViewModel) {
        _viewModel = StateObject(wrappedValue: previewViewModel)
    }

    @MainActor
    static func preview(guesses: [String] = [], input: String = "") -> some View {
        let puzzle = MidwordPuzzle(
            id: "midword-preview",
            date: "2026-10-01",
            puzzleNumber: 1,
            firstWord: "BANK",
            secondWord: "BOOK",
            answer: "NOTE",
            alternatives: []
        )
        var progress = MidwordProgress(date: puzzle.date)
        // Seed progress in memory so each canvas starts in its named state.
        let completionDate = Calendar.current.date(
            from: DateComponents(year: 2026, month: 10, day: 1, hour: 12)
        ) ?? Date()
        progress.start(at: completionDate)
        for guess in guesses {
            progress.submit(guess, for: puzzle, at: completionDate)
        }
        let viewModel = MidwordViewModel(puzzle: puzzle, progress: progress)
        for letter in input {
            viewModel.enterLetter(letter)
        }
        return NavigationStack {
            MidwordView(previewViewModel: viewModel)
        }
        .environmentObject(OverallRatingService(rating: OverallRating()))
        .environmentObject(StoreService())
    }
}

#Preview("Active — Light") {
    MidwordView.preview()
        .environment(\.colorScheme, .light)
}

#Preview("Active — Dark") {
    MidwordView.preview()
        .environment(\.colorScheme, .dark)
}

#Preview("In progress") {
    MidwordView.preview(guesses: ["PAGE", "WORD"], input: "NO")
}

#Preview("Won — 3 guesses") {
    MidwordView.preview(guesses: ["PAGE", "WORD", "NOTE"])
}

#Preview("Still playing — 5 guesses") {
    MidwordView.preview(guesses: ["PAGE", "WORD", "BOOK", "READ", "LINE"])
}

#Preview("Accessibility") {
    MidwordView.preview(guesses: ["PAGE"], input: "NO")
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
