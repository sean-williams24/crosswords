import SwiftUI

struct PuzzleView: View {
    @StateObject var viewModel: GameViewModel
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    @State private var showRewardedHintBanner = false
    @State private var isKeyboardReady = false

    private let freeHintLimit = 2

    private var isZoomableGrid: Bool {
        viewModel.puzzle.size > 12
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom navigation bar
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
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 4)

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

                // Grid
                if isZoomableGrid {
                    ZoomableView(minZoom: 1.0, maxZoom: 2.5) {
                        PuzzleGridView(viewModel: viewModel)
                            .padding(.horizontal, AppLayout.screenPadding)
                    }
                } else {
                    PuzzleGridView(viewModel: viewModel)
                        .padding(.horizontal, AppLayout.screenPadding)
                }

                Spacer(minLength: 8)

                // Invisible keyboard capture
                if isKeyboardReady {
                    KeyboardInputView(viewModel: viewModel)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $viewModel.showClueList) {
            ClueListView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isComplete) {
            CompletionView(viewModel: viewModel)
                .environmentObject(statsService)
                .environmentObject(storeService)
                .environmentObject(adService)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isKeyboardReady = true
            }
        }
        .onTapGesture {
            viewModel.deactivateZenMode()
        }
    }

    // MARK: - Rewarded Hint Banner

    private var rewardedHintBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.appAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Want a free hint?")
                    .font(AppFont.clueLabel(13))
                    .foregroundColor(.appTextPrimary)
                Text("Watch a short ad to earn one.")
                    .font(AppFont.caption(12))
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            Button {
                adService.showRewardedAd {
                    viewModel.adBonusHints += 1
                    withAnimation {
                        showRewardedHintBanner = false
                    }
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

            Button {
                showPaywall = true
            } label: {
                Text("Unlimited")
                    .font(AppFont.clueLabel(12))
                    .foregroundColor(.appAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.appAccent.opacity(0.12))
                    .cornerRadius(10)
            }

            Button {
                withAnimation {
                    showRewardedHintBanner = false
                }
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
            viewModel.showClueList = true
        } label: {
            Image(systemName: "list.bullet")
                .frame(width: 44)
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
                Image(systemName: "lightbulb")
                    .frame(height: 44)
                if !storeService.isProUser {
                    Text("\(max(0, freeHintLimit + viewModel.adBonusHints - viewModel.progress.hintedClueIds.count))")
                        .font(AppFont.caption())
                }
            }
            .foregroundColor(storeService.isProUser || viewModel.activeClueIsHinted || viewModel.progress.hintedClueIds.count < freeHintLimit + viewModel.adBonusHints ? .appAccent : .appTextSecondary)
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
