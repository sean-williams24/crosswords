import SwiftUI

struct PuzzleView: View {
    @StateObject var viewModel: GameViewModel
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @State private var showPaywall = false

    private let freeHintLimit = 2

    private var isZoomableGrid: Bool {
        viewModel.puzzle.size > 12
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .opacity(viewModel.isZenMode ? 0.2 : 1.0)

                Spacer(minLength: 8)

                // Clue bar
                ClueBarView(viewModel: viewModel)
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.bottom, 12)

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
                KeyboardInputView(viewModel: viewModel)
                    .frame(width: 0, height: 0)
                    .opacity(0)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                toolbarButtons
                    .opacity(viewModel.isZenMode ? 0.2 : 1.0)
            }
        }
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
        .navigationBarBackButtonHidden(viewModel.isZenMode)
        .onTapGesture {
            viewModel.deactivateZenMode()
        }
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
                .foregroundColor(.appTextPrimary)
        }

        Button {
            if storeService.isProUser || viewModel.activeClueIsHinted || viewModel.progress.hintedClueIds.count < freeHintLimit {
                viewModel.useHint()
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "lightbulb")
                if !storeService.isProUser {
                    Text("\(max(0, freeHintLimit - viewModel.progress.hintedClueIds.count))")
                        .font(AppFont.caption())
                }
            }
            .foregroundColor(storeService.isProUser || viewModel.activeClueIsHinted || viewModel.progress.hintedClueIds.count < freeHintLimit ? .appAccent : .appTextSecondary)
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
