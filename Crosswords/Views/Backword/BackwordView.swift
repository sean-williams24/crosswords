import SwiftUI

struct BackwordView: View {
    @StateObject private var viewModel: BackwordViewModel
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    @State private var showCategoryHint = false
    @FocusState private var inputFocused: Bool

    init(word: BackwordWord) {
        _viewModel = StateObject(wrappedValue: BackwordViewModel(word: word))
    }

    fileprivate init(viewModel: BackwordViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

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

            VStack(spacing: 0) {
                navBar
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        revealedLetterRow

                        if !viewModel.isComplete && viewModel.currentInput.count == viewModel.unrevealedCount {
                            submitButton
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }

                        guessCounter

                        if !viewModel.progress.guesses.isEmpty {
                            guessHistory
                        }

                        if viewModel.isComplete {
                            completionBanner
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            hintRow
                        }
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
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
    }

    // MARK: - Nav Bar

    private var navBar: some View {
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

            Text("BACKWORD")
                .font(AppFont.clueLabel(14))
                .foregroundColor(.appTextPrimary)
                .tracking(3)

            Spacer()

            // Balance the back button
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.clear)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Letter Row

    private var revealedLetterRow: some View {
        let inputChars = Array(viewModel.currentInput)
        let unrevealed = viewModel.unrevealedCount

        return HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { i in
                let revealed = viewModel.revealedLetters[i]
                let isInputCell = i < unrevealed && !viewModel.isComplete
                let inputChar: Character? = (isInputCell && i < inputChars.count) ? inputChars[i] : nil
                let showCursor = isInputCell && i == inputChars.count && inputFocused

                BackwordLetterCell(
                    letter: revealed,
                    inputLetter: inputChar,
                    isCursor: showCursor,
                    isNew: viewModel.newlyRevealedIndex == i
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.revealedLetters[i] != nil)
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
        Text("Guess \(viewModel.guessCount) / \(viewModel.maxGuesses)")
            .font(AppFont.caption())
            .foregroundColor(.appTextSecondary)
    }

    // MARK: - Guess History

    private var guessHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(viewModel.progress.guesses.enumerated()), id: \.offset) { index, guess in
                let isLast = index == viewModel.progress.guesses.count - 1
                let isWinRow = viewModel.isWon && isLast

                BackwordGuessRow(
                    guess: guess,
                    matchingLetters: viewModel.lettersInWord(for: guess),
                    showFeedback: viewModel.showLetterFeedback && storeService.isProUser,
                    isWinningGuess: isWinRow
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hint Row

    private var hintRow: some View {
        HStack(spacing: 12) {
            // Category hint
            Button {
                viewModel.revealCategoryHint()
                if viewModel.progress.categoryHintUsed {
                    withAnimation { showCategoryHint = true }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.progress.categoryHintUsed ? "tag.fill" : "tag")
                        .font(.system(size: 13))
                    if viewModel.progress.categoryHintUsed && showCategoryHint {
                        Text(viewModel.word.category)
                            .font(AppFont.caption())
                    } else {
                        Text("Category")
                            .font(AppFont.caption())
                    }
                }
                .foregroundColor(viewModel.progress.categoryHintUsed ? .appAccent : .appTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.appSurface)
                .cornerRadius(20)
            }

            // Letter feedback toggle hint (pro only)
            if storeService.isProUser {
                NavigationLink(value: "settings") {
                    HStack(spacing: 6) {
                        Image(systemName: AppSettings.shared.backwordLetterFeedback ? "lightbulb.fill" : "lightbulb")
                            .font(.system(size: 13))
                        Text("Letter Hints")
                            .font(AppFont.caption())
                    }
                    .foregroundColor(AppSettings.shared.backwordLetterFeedback ? .appAccent : .appTextSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.appSurface)
                    .cornerRadius(20)
                }
            }

            Spacer()
        }
    }

    // MARK: - Completion Banner

    private var completionBanner: some View {
        VStack(spacing: 16) {
            if viewModel.isWon {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.appCorrect)

                    Text("Well done!")
                        .font(AppFont.header(22))
                        .foregroundColor(.appTextPrimary)

                    Text("Got it in \(viewModel.guessCount) guess\(viewModel.guessCount == 1 ? "" : "es")")
                        .font(AppFont.body(15))
                        .foregroundColor(.appTextSecondary)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.red.opacity(0.7))

                    Text("The word was")
                        .font(AppFont.body(15))
                        .foregroundColor(.appTextSecondary)

                    Text(viewModel.word.word)
                        .font(AppFont.header(28))
                        .foregroundColor(.appTextPrimary)
                        .tracking(4)
                }
            }

            // Definition
            Text(viewModel.word.definition)
                .font(AppFont.clueText())
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            shareButton
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(AppLayout.cardCornerRadius)
    }

    private var shareButton: some View {
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
                Text("Share result")
            }
            .font(AppFont.body(15))
            .foregroundColor(.appAccent)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.appAccent.opacity(0.1))
            .cornerRadius(20)
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
}

#Preview("Won — 3 guesses") {
    var progress = BackwordProgress(date: previewWord.date)
    progress.guesses = ["BRIDGX", "FXASXE", "CASTLE"]  // 2 wrong + 1 correct
    progress.wonFlag = true
    progress.completedAt = Date()
    let vm = BackwordViewModel(word: previewWord, progress: progress)
    return BackwordView(viewModel: vm)
        .environmentObject(StoreService())
}

#Preview("Failed — 5 guesses") {
    var progress = BackwordProgress(date: previewWord.date)
    progress.guesses = ["BRXXLE", "FOXXLE", "PLXXLE", "MAXXLE", "SIXXLE"]
    progress.wonFlag = false
    progress.completedAt = Date()
    let vm = BackwordViewModel(word: previewWord, progress: progress)
    return BackwordView(viewModel: vm)
        .environmentObject(StoreService())
}
