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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var ratingService: OverallRatingService
    @State private var sheetPresentation = MidwordSheetPresentation()
    @State private var shouldPopAfterCompletionSheet = false

    private var appLayout: AppLayout { AppLayout(sizeClass: sizeClass) }

    init(puzzle: MidwordPuzzle) {
        _viewModel = StateObject(wrappedValue: MidwordViewModel(puzzle: puzzle))
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 0) {
                        navBar
                        gameContent
                        inputControls
                    }
                }
            } else {
                VStack(spacing: 0) {
                    navBar
                    ScrollView { gameContent }
                    inputControls
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.canSubmit)
        .background(Color.midwordBackground.ignoresSafeArea())
        .blur(radius: sheetPresentation.isPresentingSheet ? AppLayout.sheetBackgroundBlurRadius : 0)
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .navigationBarBackButtonHidden()
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
            Text("Find the link that ends the top word and starts the bottom word to make 2 new words")
                .font(AppFont.body())
                .foregroundColor(.midwordText.opacity(0.85))
                .multilineTextAlignment(.center)
            MidwordBoardView(puzzle: viewModel.puzzle, input: viewModel.input, won: viewModel.progress.isWon)
            MidwordAttemptCounterView(progress: viewModel.progress)
            if let message = viewModel.message {
                Text(message).font(AppFont.body()).foregroundColor(.midwordText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .transition(.opacity)
            }
            if !viewModel.progress.guesses.isEmpty {
                VStack(alignment: .center, spacing: 10) {
                    Text("Previous guesses").font(AppFont.caption())
                    ForEach(Array(viewModel.progress.guesses.enumerated()), id: \.offset) { _, guess in
                        MidwordGuessRow(guess: guess, isCorrect: viewModel.puzzle.accepts(guess))
                    }
                }
                .foregroundColor(.midwordText)
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
        if !viewModel.isComplete {
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
            }
        }
    }

    private var navBar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    navTitle
                    navControls
                }
            } else {
                ZStack {
                    navTitle
                    navControls
                }
            }
        }
        .foregroundColor(.midwordText)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 12)
    }

    private var navTitle: some View {
        Image("MidwordLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 38)
    }

    private var navControls: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .frame(width: appLayout.iconSize, height: appLayout.iconSize)
            }
            .accessibilityLabel("Back")
            Spacer()
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

#Preview("Active") {
    MidwordView.preview()
}

#Preview("In progress") {
    MidwordView.preview(guesses: ["PAGE", "WORD"], input: "NO")
}

#Preview("Won — 3 guesses") {
    MidwordView.preview(guesses: ["PAGE", "WORD", "NOTE"])
}

#Preview("Failed — 5 guesses") {
    MidwordView.preview(guesses: ["PAGE", "WORD", "BOOK", "READ", "LINE"])
}

#Preview("Accessibility") {
    MidwordView.preview(guesses: ["PAGE"], input: "NO")
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
