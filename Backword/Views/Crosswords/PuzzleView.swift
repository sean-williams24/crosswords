import SwiftUI

struct PuzzleView: View {
    @StateObject var viewModel: GameViewModel
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @EnvironmentObject var ratingService: OverallRatingService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var buttonWidth: CGFloat = 60
    @State private var showPaywall = false
    @State private var showRewardedHintBanner = false
    @State private var showCrosswordStats = false
    @State private var isKeyboardReady = false
    @State private var layoutKeyboardHeight: CGFloat = 0
    @State private var suppressKeyboardUpdate = false
    @State private var shouldPopAfterCompletionSheet = false
    private let freeHintLimit = 0

    private var isZoomableGrid: Bool {
        viewModel.puzzle.size > 12
    }

    private var navigationBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                    .padding(.vertical, 8)
            }
            .opacity(viewModel.isZenMode ? 0.2 : 1.0)

            Spacer()

            toolbarButtons
                .opacity(viewModel.isZenMode ? 0.2 : 1.0)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 4)
    }
    
    var body: some View {
        ZStack {
            AppBackgroundGradient()
            
            VStack(spacing: 0) {
                navigationBar
                
                // Rewarded hint banner
                if showRewardedHintBanner {
                    rewardedHintBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Header
                VStack(spacing: 12) {
                    header
                        .opacity(viewModel.isZenMode ? 0.2 : 1.0)
                    
                    // Clue bar
                    ClueBarView(viewModel: viewModel)
                        .padding(.horizontal, AppLayout.screenPadding)
                        .padding(.bottom, 12)
                }
                
                Spacer(minLength: 8)
                
                ZoomableView(allowsVerticalOverflow: true) {
                    PuzzleGridView(viewModel: viewModel)
                        .padding(.horizontal, AppLayout.screenPadding)
                        .dynamicTypeSize(.medium)
                }
                
                Spacer(minLength: 8)
                CustomKeyboardView { text in
                    Task { @MainActor in
                        if let char = text.uppercased().first,
                           char.isLetter {
                            viewModel.enterLetter(char)
                        }
                    }
                } onDelete: {
                    Task { @MainActor in
                        viewModel.deleteLetter()
                    }
                }
            }
            .padding(.bottom, layoutKeyboardHeight)
        }
        .ignoresSafeArea(.keyboard)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .sheet(isPresented: $viewModel.showClueList) {
            ClueListView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(
            isPresented: $viewModel.isComplete,
            onDismiss: {
                if shouldPopAfterCompletionSheet {
                    dismiss()
                }
            }
        ) {
            CompletionView(viewModel: viewModel, shouldPop: $shouldPopAfterCompletionSheet)
                .environmentObject(statsService)
                .environmentObject(storeService)
                .environmentObject(adService)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
        }
        .sheet(isPresented: $showCrosswordStats) {
            CrosswordStatsView(isWeekly: viewModel.puzzle.size > 12) { showCrosswordStats = false }
                .environmentObject(statsService)
                .environmentObject(ratingService)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Delay keyboard appearance until after the navigation push animation
            // completes (~0.35s), for both grid sizes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isKeyboardReady = true
            }
        }
        .onDisappear {
            // Ensure metadata is saved for rating backfill
            if viewModel.progress.puzzleDate == nil {
                viewModel.progress.puzzleDate = viewModel.puzzle.date
                viewModel.progress.totalClues = viewModel.puzzle.clues.count
                viewModel.progress.isWeekly = viewModel.puzzle.size > 12
                viewModel.progress.save()
            }
            // Record partial or complete progress whenever the user leaves the puzzle
            let completed = viewModel.progress.completedClueIds.count
            let total = viewModel.puzzle.clues.count
            let date = viewModel.puzzle.date
            let hintsUsed = viewModel.progress.hintsUsed
            if viewModel.puzzle.size > 12 {
                ratingService.recordWeeklyCrossword(completedClues: completed, totalClues: total, date: date, hintsUsed: hintsUsed)
            } else {
                ratingService.recordDailyCrossword(completedClues: completed, totalClues: total, date: date, hintsUsed: hintsUsed)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
//        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notif in
//            guard !suppressKeyboardUpdate else { return }
//            let endFrame = (notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
//            let screenHeight = UIScreen.main.bounds.height
//            let rawHeight = max(0, screenHeight - endFrame.origin.y)
//            // The keyboard frame includes the bottom safe area (home indicator), but the
//            // VStack already respects it naturally — subtract to avoid double-counting.
//            let safeAreaBottom = UIApplication.shared.connectedScenes
//                .compactMap { $0 as? UIWindowScene }
//                .first?.windows.first(where: { $0.isKeyWindow })?
//                .safeAreaInsets.bottom ?? 0
//            let height = max(0, rawHeight - safeAreaBottom)
//            let duration = (notif.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
//            withAnimation(.easeInOut(duration: duration)) {
//                layoutKeyboardHeight = height
//            }
//        }
//        .onChange(of: viewModel.showClueList) { _, isShowing in
//            handleKeyboardSurpression(if: isShowing)
//            
//        }
//        .onChange(of: showCrosswordStats) { _, isShowing in
//            handleKeyboardSurpression(if: isShowing)
//        }
//        .onChange(of: showPaywall) { _, isShowing in
//            handleKeyboardSurpression(if: isShowing)
//        }
//        .onChange(of: viewModel.isComplete) { _, isShowing in
//            handleKeyboardSurpression(if: isShowing)
//        }
//        .onTapGesture {
//            viewModel.deactivateZenMode()
//        }
//    }
//
//    private func handleKeyboardSurpression(if isShowing: Bool) {
//        if isShowing {
//            suppressKeyboardUpdate = true
//        } else {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { suppressKeyboardUpdate = false }
//        }
//    }

    // MARK: - Rewarde
    private let hintIcon: some View = Image(systemName: "play.circle.fill")
        .font(.system(size: 24))
        .foregroundColor(.appAccent)

    private var bannerTextStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Want a free hint?")
                .font(AppFont.clueLabel(13))
                .foregroundColor(.appTextPrimary)
            Text("Watch a short ad to earn one.")
                .font(AppFont.caption(12))
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var watchButton: some View {
        Button {
            adService.showRewardedAd {
                viewModel.adBonusHints += 1
                withAnimation {
                    showRewardedHintBanner = false
                }
            }
        } label: {
            Text("Watch")
                .frame(maxWidth: .infinity)
                .font(AppFont.clueLabel(12))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.appAccent)
                .cornerRadius(10)
        }
    }

    private var unlimitedButton: some View {
        Button {
            showPaywall = true
        } label: {
            Text("Unlimited")
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity)
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.appAccent.opacity(0.12))
                .cornerRadius(10)
        }
    }

    private var closeButton: some View {
        Button {
            withAnimation {
                showRewardedHintBanner = false
            }
        } label: {
            Image(systemName: "xmark")
                .font(.body)
                .foregroundColor(.appTextSecondary)
        }
    }

    private var hRewardedHintBanner: some View {
        HStack(spacing: 12) {
            hintIcon
            bannerTextStack
            Spacer()
            ViewThatFits {
                HStack {
                    watchButton
                    unlimitedButton
                }
                VStack {
                    watchButton
                    unlimitedButton
                }
            }

            closeButton
        }
    }

    private var vRewardedHintBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                bannerTextStack
                Spacer(minLength: 0)
                closeButton
            }
            HStack {
                watchButton
                unlimitedButton
            }
        }
    }

    private var rewardedHintBanner: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                vRewardedHintBanner
            } else {
                hRewardedHintBanner
            }
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 12)
        .background(Color.appSurface)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 2) {
            ZStack {
                Text(viewModel.puzzle.date)
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
                    .tracking(1)
                    .opacity(viewModel.showAlreadyAnswered ? 0 : 1)

                Text("Already answered")
                    .font(AppFont.caption())
                    .foregroundColor(.appAccent)
                    .tracking(1)
                    .opacity(viewModel.showAlreadyAnswered ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.4), value: viewModel.showAlreadyAnswered)
        }
        .padding(.top, 8)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarButtons: some View {
        Button {
            showCrosswordStats = true
        } label: {
            Image(systemName: "brain.head.profile")
                .frame(width: 34)
                .foregroundColor(.appTextPrimary)
        }

        Button {
            viewModel.showClueList = true
        } label: {
            Image(systemName: "list.bullet")
                .frame(width: 34)
                .foregroundColor(.appTextPrimary)
        }

        Button {
            let totalAllowed = freeHintLimit + viewModel.adBonusHints
            if storeService.isProUser || viewModel.activeClueIsHinted || viewModel.progress.hintedClueIds.count < totalAllowed {
                viewModel.useHint()
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showRewardedHintBanner = true
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.activeClueIsHinted ? "lightbulb.fill" : "lightbulb")
                    .frame(height: 44)
                let hintsRemaining = storeService.isProUser ? 1 : max(0, freeHintLimit + viewModel.adBonusHints - viewModel.progress.hintedClueIds.count)
                Text(viewModel.activeClueIsHinted || hintsRemaining > 0 ? "Hint" : "Get hint")
                    .font(AppFont.body(13))
            }
            .foregroundColor(viewModel.activeClueIsHinted ? .appCorrect : .appAccent)
        }
    }
}

#Preview {
    NavigationStack {
        PuzzleView(viewModel: GameViewModel(puzzle: .sample))
            .environmentObject(StatsService())
            .environmentObject(StoreService())
            .environmentObject(AdService())
    }
}

#Preview {
    NavigationStack {
        PuzzleView(viewModel: GameViewModel(puzzle: .sample13x13))
            .environmentObject(StatsService())
            .environmentObject(StoreService())
            .environmentObject(AdService())
    }
}

