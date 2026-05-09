import SwiftUI

struct BackwordView: View {
    @StateObject private var viewModel: BackwordViewModel
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @Environment(\.dismiss) private var dismiss

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
            // Hidden TextField — captures keyboard input; focused programmatically.
            TextField("", text: Binding(
                get: { viewModel.currentInput },
                set: { viewModel.onInputChange($0) }
            ))
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .focused($inputFocused)
            .onSubmit { viewModel.submitGuess() }
            .opacity(0.001)
            .frame(width: 1, height: 1)

            VStack(alignment: .center, spacing: 0) {
                navBar
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 24) {
                        hintRow
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
                inputFocused = true
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.currentInput.count == viewModel.unrevealedCount)
        .animation(.easeInOut(duration: 0.3), value: viewModel.invalidWordMessage != nil)
        .onChange(of: viewModel.isComplete) { complete in
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

                HStack(spacing: 16) {
                    Button {
                        statsService.refresh()
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.vertical, 8)
                            .foregroundColor(viewModel.statsIconColour)
                            .scaleEffect(pulses ? 0.7 : 1.3)
                            .opacity(pulses ? 0.44 : 0.8)
                    }

                    Button {
                        showInstructions = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                            .padding(.vertical, 8)
                    }
                    .sheet(isPresented: $showInstructions) {
                        instructionsSheet
                    }
                }
            }
        }
    }

    // MARK: - Instructions Sheet

    private var instructionsSheet: some View {
        NavigationStack {
            instructionsContent
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var instructionsContent: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                instructionRow(number: "1", text: "Guess the 6-letter word in 5 tries.")
                instructionRow(number: "2", text: "The last letter and the third letter are revealed to start. Each wrong guess reveals one more letter from the right.")
                instructionRow(number: "3", text: "Type the missing letters into the highlighted cells, then tap Submit.")
                instructionRow(number: "4", text: "The category is shown at the top — it's your clue")
            }

            Divider()
                .background(Color.appGridLine)

            HStack(spacing: 12) {
                exampleCell(letter: "C", isRevealed: false)
                exampleCell(letter: "A", isRevealed: false)
                exampleCell(letter: "S", isRevealed: true)
                exampleCell(letter: "T", isRevealed: true)
                exampleCell(letter: "L", isRevealed: true)
                exampleCell(letter: "E", isRevealed: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("After 2 wrong guesses — 4 letters revealed")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(AppFont.clueLabel(13))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.appAccent)
                .clipShape(Circle())
            Text(text)
                .font(AppFont.body(14))
                .foregroundColor(.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func exampleCell(letter: String, isRevealed: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isRevealed ? Color.appAccent.opacity(0.5) : Color.appGridLine,
                            lineWidth: 1.5
                        )
                )
            Text(isRevealed ? letter : "")
                .font(AppFont.gridLetter(16))
                .foregroundColor(.appTextPrimary)
        }
        .frame(width: 36, height: 36)
    }

    // MARK: - Letter Row

    private var revealedLetterRow: some View {
        let inputChars = Array(viewModel.currentInput)
        let unrevealedIndices = viewModel.unrevealedIndices
        let wordChars = Array(viewModel.word.word.uppercased())

        return HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { i in
                if viewModel.isWon {
                    // Show full correct word in green
                    BackwordLetterCell(
                        letter: wordChars[i],
                        isCorrect: true
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
                        isNew: viewModel.newlyRevealedIndex == i
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

    private var hintRow: some View {
        HStack(spacing: 12) {
            // Category — always visible
            HStack(spacing: 6) {
//                Image(systemName: "tag.fill")
//                    .font(.system(size: 13))
                Text("Category: ")
                    .font(AppFont.clueLabel())
                    .foregroundColor(.appGridLine)

                Text(viewModel.word.category.uppercased())
                    .font(AppFont.clueLabel(16))
                    .foregroundColor(.appTextPrimary)
            }
//            .foregroundColor(.appGridLine)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
//            .background(Color.appSurface)
//            .cornerRadius(20)

            // Letter feedback toggle hint (pro only)
//            if storeService.isProUser {
//                NavigationLink(value: "settings") {
//                    HStack(spacing: 6) {
//                        Image(systemName: AppSettings.shared.backwordLetterFeedback ? "lightbulb.fill" : "lightbulb")
//                            .font(.system(size: 13))
//                        Text("Letter Hints")
//                            .font(AppFont.caption())
//                    }
//                    .foregroundColor(AppSettings.shared.backwordLetterFeedback ? .appAccent : .appTextSecondary)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 7)
//                    .background(Color.appSurface)
//                    .cornerRadius(20)
//                }
//            }

            Spacer()
        }
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
                    HStack(spacing: 8) {
                        pulsatingCross
                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedFailureMessage + " the word was...")
                                .font(AppFont.body(15))
                                .foregroundColor(.appTextSecondary)
                            HStack {
                                Spacer()
                                Text(viewModel.word.word)
                                    .font(AppFont.header(28))
                                    .foregroundColor(.red)
                                    .tracking(4)
                                    .opacity(pulses ? 0.4 : 0.8)
                                Spacer()
                            }
                        }
                        Spacer()
                        pulsatingCross
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)

            shareButton
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
    date: "2026-04-01",
    word: "CASTLE",
    category: "History",
    definition: "A large fortified building, typically medieval, used as a noble residence and stronghold."
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
