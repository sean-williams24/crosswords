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

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        revealedLetterRow

                        guessCounter

                        if !viewModel.progress.guesses.isEmpty {
                            guessHistory
                        }

                        if viewModel.isComplete {
                            completionBanner
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            inputArea
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
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { i in
                BackwordLetterCell(
                    letter: viewModel.revealedLetters[i],
                    isNew: viewModel.newlyRevealedIndex == i
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.revealedLetters[i] != nil)
            }
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

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("Enter 6 letters…", text: Binding(
                    get: { viewModel.currentInput },
                    set: { viewModel.onInputChange($0) }
                ))
                .font(AppFont.gridLetter(18))
                .foregroundColor(.appTextPrimary)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.appSurface)
                .cornerRadius(AppLayout.cardCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                        .strokeBorder(
                            viewModel.inputError ? Color.red : Color.appGridLine,
                            lineWidth: 1
                        )
                )

                Button {
                    viewModel.submitGuess()
                } label: {
                    Text("Go")
                        .font(AppFont.clueLabel(15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            viewModel.currentInput.count == 6
                                ? Color.appAccent
                                : Color.appTextSecondary.opacity(0.3)
                        )
                        .cornerRadius(AppLayout.cardCornerRadius)
                }
                .disabled(viewModel.currentInput.count != 6)
            }
        }
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

#Preview {
    BackwordView(word: BackwordWord(
        date: "2026-04-01",
        word: "CASTLE",
        category: "History",
        definition: "A large medieval fortified building."
    ))
    .environmentObject(StoreService())
}
