import SwiftUI

struct MidwordView: View {
    @StateObject private var viewModel: MidwordViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var ratingService: OverallRatingService
    @State private var showStats = false
    @State private var showInstructions = false
    @State private var showCompletion = false

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
        .background(Color.midwordBackground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .navigationBarBackButtonHidden()
        .onAppear { if viewModel.isComplete { showCompletion = true } }
        .onChange(of: viewModel.isComplete) { _, complete in
            if complete {
                ratingService.refresh()
                showCompletion = true
            }
        }
        .sheet(isPresented: $showCompletion) {
            MidwordStatsView(puzzle: viewModel.puzzle, progress: viewModel.progress, showsCompletion: true)
        }
        .sheet(isPresented: $showStats) {
            MidwordStatsView(puzzle: viewModel.puzzle, progress: viewModel.progress, showsCompletion: false)
        }
        .sheet(isPresented: $showInstructions) {
            NavigationStack {
                MidwordInstructionsView()
                    .navigationTitle("How to Play")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showInstructions = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.appTextSecondary)
                            }
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
            Text("Find the word in the middle")
                .font(AppFont.body())
                .foregroundColor(.midwordText.opacity(0.85))
            MidwordBoardView(puzzle: viewModel.puzzle, input: viewModel.input, won: viewModel.progress.isWon)
            MidwordAttemptCounterView(progress: viewModel.progress)
            if let message = viewModel.message {
                Text(message).font(AppFont.body()).foregroundColor(.midwordText)
                    .accessibilityAddTraits(.updatesFrequently)
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
    }

    @ViewBuilder
    private var inputControls: some View {
        if !viewModel.isComplete {
            VStack(spacing: 6) {
                GameScoreProgressBarView(rating: ratingService.rating, category: .midword)
                    .padding(.horizontal, AppLayout.screenPadding)
                Button("Submit") { viewModel.submitGuess() }
                    .font(AppFont.header(18))
                    .foregroundColor(.midwordOnAccent)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.midwordAccent)
                    .disabled(!viewModel.canSubmit)
                    .opacity(viewModel.canSubmit ? 1 : 0.5)
                    .padding(.horizontal, AppLayout.screenPadding)
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
        Text("MIDWORD")
            .font(AppFont.header(24))
            .accessibilityAddTraits(.isHeader)
    }

    private var navControls: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .frame(width: appLayout.iconSize, height: appLayout.iconSize)
            }
            .accessibilityLabel("Back")
            Spacer()
            Button { showStats = true } label: {
                Image(systemName: "brain.head.profile")
                    .frame(width: appLayout.iconSize, height: appLayout.iconSize)
            }
            .accessibilityLabel("Statistics")
            Button { showInstructions = true } label: {
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
