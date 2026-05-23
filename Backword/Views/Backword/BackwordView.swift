import SwiftUI

struct BackwordView: View {
    @StateObject private var viewModel: BackwordViewModel
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showInstructions = false
    @State private var showStats = false
    @State private var pulses = false
    @State private var selectedFailureMessage: String = ""
    @StateObject private var statsService = BackwordStatsService()
    @FocusState private var inputFocused: Bool

    init(word: BackwordWord) {
        _viewModel = StateObject(wrappedValue: BackwordViewModel(word: word))
    }

    fileprivate init(viewModel: BackwordViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            TextField("", text: Binding(
                get: { viewModel.currentInput },
                set: { viewModel.onInputChange($0) }
            ))
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .focused($inputFocused)
            .onSubmit { viewModel.submitGuess() }
            .frame(width: 1, height: 1)
            .opacity(0.001)
            .allowsHitTesting(false)

            VStack(alignment: .center, spacing: 0) {
                navBar
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 24) {
                        if isIpad {
                            Spacer()
                                .frame(height: 100)
                        }
                        categoryView
                        revealedLetterRow

                        if let message = viewModel.invalidWordMessage {
                            Text(message)
                                .font(AppFont.caption(16))
                                .foregroundColor(.red.opacity(0.6))
                                .transition(.opacity)
                        }

                        guessCounter

                        if !viewModel.progress.guesses.isEmpty {
                            guessHistory
                        }

                        if viewModel.isComplete {
                            completionBanner
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding([.top, .bottom], 16)
                }
                .safeAreaInset(edge: .bottom) {
                    if !viewModel.isComplete && viewModel.currentInput.count == viewModel.unrevealedCount {
                        submitButton
                            .padding(.horizontal, AppLayout.screenPadding)
                            .padding(.vertical, 12)
                            .background(Color.appBackground)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if !viewModel.isComplete {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    inputFocused = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentInput.count == viewModel.unrevealedCount)
        .animation(.easeInOut(duration: 0.3), value: viewModel.invalidWordMessage != nil)
        .onChange(of: viewModel.isComplete) { _, complete in
            if complete {
                inputFocused = false
                statsService.refresh()
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
//                    showStats = true
//                }
            }
        }
        .sheet(isPresented: $showStats) {
            BackwordStatsView(
                stats: statsService.stats,
                highlightGuessCount: viewModel.isWon ? viewModel.guessCount : nil
            ) { showStats = false }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var isIpad: Bool {
        sizeClass == .regular
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        ZStack {
            // Centre title always perfectly centred
            BackwordLogo()

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                        .padding(.vertical, 8)
                }

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        statsService.refresh()
                        showStats = true
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .frame(width: 34)
                            .padding(.vertical, 8)
                            .foregroundColor(viewModel.statsIconColour)
                            .scaleEffect(pulses ? 0.7 : 1)
                            .opacity(pulses ? 0.44 : 0.8)
                    }

                    Button {
                        showInstructions = true
                    } label: {
                        Image(systemName: "info.circle")
                            .frame(width: 34)
                            .foregroundColor(.appTextPrimary)
                            .padding(.vertical, 8)
                    }
                    .sheet(isPresented: $showInstructions) {
                        instructionsSheet
                    }
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    // MARK: - Instructions Sheet

    private var instructionsSheet: some View {
        NavigationStack {
            BackwordInstructionsContentView()
                .navigationTitle("How to Play")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showInstructions = false
                        } label: {
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

    // MARK: - Letter Row

    private var revealedLetterRow: some View {
        let inputChars = Array(viewModel.currentInput)
        let unrevealedIndices = viewModel.unrevealedIndices
        let wordChars = Array(viewModel.word.word.uppercased())
        let size: CGFloat = isIpad ? 84 : 44

        return HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { i in
                if viewModel.isWon {
                    // Show full correct word in green
                    BackwordLetterCell(
                        letter: wordChars[i],
                        isCorrect: true,
                        size: size
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(i) * 0.06), value: viewModel.isWon)
                } else {
                    let revealed = viewModel.revealedLetters[i]
                    let inputIndex = unrevealedIndices.firstIndex(of: i)
                    let isInputCell = inputIndex != nil && !viewModel.isComplete
                    let inputChar: Character? = isInputCell ? (inputIndex! < inputChars.count ? inputChars[inputIndex!] : nil) : nil
                    let showCursor = isInputCell && inputIndex! == inputChars.count && inputFocused

                    BackwordLetterCell(
                        letter: revealed,
                        inputLetter: inputChar,
                        isCursor: showCursor,
                        isNew: viewModel.newlyRevealedIndex == i,
                        size: size
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.revealedLetters[i] != nil)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !viewModel.isComplete { inputFocused = true } }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            viewModel.submitGuess()
        } label: {
            Text("Submit")
                .font(AppFont.clueLabel(15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appAccent)
                .cornerRadius(AppLayout.cardCornerRadius)
        }
    }

    // MARK: - Guess Counter

    private var guessCounter: some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.maxGuesses, id: \.self) { i in
                let isUsed = i < viewModel.guessCount
                let isWinSlot = viewModel.isWon && i == viewModel.guessCount - 1

                var guessCounterColour: Color {
                    if viewModel.isFailed {
                        return .red
                    }
                    return isWinSlot ? Color.appCorrect : isUsed ? Color.appAccent.opacity(0.7) : Color.appSurface
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(guessCounterColour)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(
                                isWinSlot ? Color.appCorrect : isUsed ? Color.appAccent.opacity(0.5) : Color.appGridLine,
                                lineWidth: 1
                            )
                    )
                    .frame(width: 36, height: 10)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.guessCount)
            }
        }
    }

    // MARK: - Guess History

    private var guessHistory: some View {
        // When won, the winning guess is shown in the letter row — exclude it here
        let guesses = viewModel.isWon
            ? Array(viewModel.progress.guesses.dropLast())
            : viewModel.progress.guesses

        return VStack(alignment: .center, spacing: 8) {
            ForEach(Array(guesses.enumerated()), id: \.offset) { _, guess in
                BackwordGuessRow(
                    guess: guess,
                    matchingLetters: viewModel.lettersInWord(for: guess),
                    showFeedback: viewModel.showLetterFeedback && storeService.isProUser,
                    isWinningGuess: false
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Hint Row

    private var categoryView: some View {
        HStack(spacing: 12) {
            ViewThatFits {
                HStack(spacing: 6) {
                    categoryContent
                }
                VStack(alignment: .leading) {
                    categoryContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)

            Spacer()
        }
    }

    @ViewBuilder
    private var categoryContent: some View {
        Text("Clue: ")
            .font(AppFont.clueLabel(isIpad ? 25 : 16))
            .foregroundColor(.appAccent)

        Text(viewModel.word.clue.uppercased())
            .font(AppFont.clueLabel(isIpad ? 30 : 19 ))
            .foregroundColor(.appTextPrimary)
    }

    // MARK: - Completion Banner

    private var failureMessages: [String] {
        [
            "It's good, but it's not the one,",
            "That's unfortunate,",
            "Solid efforts, but"
        ]
    }

    private var successMessages: [String] {
        [
            " nice work.",
            " well played.",
            " solid efforts."
        ]
    }

    private var completionBanner: some View {
        VStack(spacing: 16) {
            VStack {
                if viewModel.isWon {
                    VStack(spacing: 8) {
                        Text("Completed in \(viewModel.guessCount) guess\(viewModel.guessCount == 1 ? "" : "es"), \(successMessages.randomElement() ?? "")")
                            .font(AppFont.body(15))
                            .foregroundColor(.appTextSecondary)
                    }
                } else {
                    VStack(alignment: .center, spacing: 8) {
                        Text(selectedFailureMessage + " the word was...")
                            .font(AppFont.body(15))
                            .foregroundColor(.appTextSecondary)
                        Text(viewModel.word.word)
                            .font(AppFont.header(28))
                            .foregroundColor(.red)
                            .tracking(4)
                            .opacity(pulses ? 0.4 : 0.8)
                    }
                }
            }
            .padding(20)
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)

//            shareButton
        }
        .onAppear {
            if selectedFailureMessage.isEmpty {
                selectedFailureMessage = failureMessages.randomElement() ?? "Game Over"
            }
        }
    }

    private var pulsatingCross: some View {
        Image(systemName: "xmark.circle")
            .font(.system(size: 26))
            .foregroundColor(.red.opacity(0.5))
            .opacity(pulses ? 0.08 : 0.8)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                ) {
                    pulses = true
                }
            }
    }

    private var shareButton: some View {
        HStack {
            Spacer()
            Button {
                let text = viewModel.shareText
                let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let root = window.rootViewController {
                    root.present(av, animated: true)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(AppFont.body(15))
                .foregroundColor(.appAccent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
//                .background(Color.appAccent.opacity(0.1))
                .cornerRadius(20)
            }
        }
    }
}

// MARK: - Previews

private let previewWord = BackwordWord(
    id: "",
    date: "2026-04-01",
    word: "CASTLE",
    clue: "CHESS"
)

#Preview("Active") {
    BackwordView(word: previewWord)
        .environmentObject(StoreService())
        .environmentObject(AdService())
}

#Preview("Won — 3 guesses") {
    var progress = BackwordProgress(date: previewWord.date)
    progress.guesses = ["BRIDGX", "FXASXE", "CASTLE"]  // 2 wrong + 1 correct
    progress.wonFlag = true
    progress.completedAt = Date()
    let vm = BackwordViewModel(word: previewWord, progress: progress)
    return BackwordView(viewModel: vm)
        .environmentObject(StoreService())
        .environmentObject(AdService())
}

#Preview("Failed — 5 guesses") {
    var progress = BackwordProgress(date: previewWord.date)
    progress.guesses = ["BRXXLE", "FOXXLE", "PLXXLE", "MAXXLE", "SIXXLE"]
    progress.wonFlag = false
    progress.completedAt = Date()
    let vm = BackwordViewModel(word: previewWord, progress: progress)
    return BackwordView(viewModel: vm)
        .environmentObject(StoreService())
        .environmentObject(AdService())
}
