import SwiftUI

struct BackwordView: View {
    @StateObject private var viewModel: BackwordViewModel
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @Environment(\.dismiss) private var dismiss

    @State private var showInstructions = false
    @State private var showRewardedCategoryBanner = false
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

            VStack(alignment: .center, spacing: 0) {
                navBar
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 24) {
                        revealedLetterRow

                        guessCounter

                        if !viewModel.progress.guesses.isEmpty {
                            guessHistory
                        }

                        if viewModel.isComplete {
                            completionBanner
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            hintRow
                        }
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
                .safeAreaInset(edge: .top) {
                    if showRewardedCategoryBanner {
                        rewardedCategoryBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
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
        .onChange(of: viewModel.isComplete) { complete in
            if complete { inputFocused = false }
        }
        .onChange(of: viewModel.categoryHintRevealed) { revealed in
            if revealed { withAnimation { showRewardedCategoryBanner = false } }
        }
    }

    // MARK: - Rewarded Category Banner

    private var rewardedCategoryBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.appAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reveal the category?")
                    .font(AppFont.clueLabel(13))
                    .foregroundColor(.appTextPrimary)
                Text("Watch a short ad to unlock it.")
                    .font(AppFont.caption(12))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            Button {
                adService.showRewardedAd {
                    viewModel.revealCategoryHint()
                }
            } label: {
                Text("Watch")
                    .font(AppFont.clueLabel(12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.appAccent)
                    .cornerRadius(10)
            }
//            .disabled(!adService.isRewardedAdReady)

            Button {
                withAnimation { showRewardedCategoryBanner = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 12)
        .background(Color.appSurface)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
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

            Button {
                showInstructions = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                    .padding(.vertical, 8)
            }
            .popover(isPresented: $showInstructions, arrowEdge: .top) {
                instructionsPopover
            }
        }
    }

    // MARK: - Instructions Popover

    private var instructionsPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Play")
                .font(AppFont.header(18))
                .foregroundColor(.appTextPrimary)

            VStack(alignment: .leading, spacing: 10) {
                instructionRow(number: "1", text: "Guess the 6-letter word in 5 tries.")
                instructionRow(number: "2", text: "The last letter is revealed to start. Each wrong guess reveals one more letter from the right.")
                instructionRow(number: "3", text: "Type the missing letters into the highlighted cells, then tap Submit.")
                instructionRow(number: "4", text: "Tap the category tag for a free hint.")
            }

            Divider()
                .background(Color.appGridLine)

            HStack(spacing: 12) {
                exampleCell(letter: "C", isRevealed: false)
                exampleCell(letter: "A", isRevealed: false)
                exampleCell(letter: "S", isRevealed: false)
                exampleCell(letter: "T", isRevealed: true)
                exampleCell(letter: "L", isRevealed: true)
                exampleCell(letter: "E", isRevealed: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("After 2 wrong guesses — 3 letters revealed")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .frame(width: 300)
        .background(Color.appBackground)
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
        HStack(spacing: 6) {
            ForEach(0..<viewModel.maxGuesses, id: \.self) { i in
                let isUsed = i < viewModel.guessCount
                let isWinSlot = viewModel.isWon && i == viewModel.guessCount - 1

                RoundedRectangle(cornerRadius: 3)
                    .fill(isWinSlot ? Color.appCorrect : isUsed ? Color.appAccent.opacity(0.7) : Color.appSurface)
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
        VStack(alignment: .center, spacing: 8) {
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
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Hint Row

    private var hintRow: some View {
        HStack(spacing: 12) {
            // Category hint
            Button {
                if storeService.isProUser && !viewModel.categoryHintRevealed {
                    // Pro: reveal for free
                    viewModel.revealCategoryHint()
                } else if !viewModel.categoryHintRevealed {
                    // Free user — prompt rewarded ad
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showRewardedCategoryBanner = true
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.categoryHintRevealed ? "tag.fill" : "tag")
                        .font(.system(size: 13))
                    if viewModel.categoryHintRevealed {
                        Text(viewModel.word.category)
                            .font(AppFont.caption())
                    } else {
                        Text("Category")
                            .font(AppFont.caption())
                    }
                }
                .foregroundColor(viewModel.categoryHintRevealed ? .appAccent : .appTextSecondary)
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
            VStack {
                if viewModel.isWon {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.appCorrect)
                        //
                        //                    Text("Well done!")
                        //                        .font(AppFont.header(22))
                        //                        .foregroundColor(.appTextPrimary)

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
            }
            .padding(20)
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)

            shareButton
        }
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
                Text("Share")
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
