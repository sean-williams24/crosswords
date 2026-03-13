import SwiftUI

struct PuzzleView: View {
    @StateObject var viewModel: GameViewModel
    @EnvironmentObject var statsService: StatsService
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService

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
                PuzzleGridView(viewModel: viewModel)
                    .padding(.horizontal, AppLayout.screenPadding)

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
        .navigationBarBackButtonHidden(viewModel.isZenMode)
        .onTapGesture {
            viewModel.deactivateZenMode()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 2) {
//            Text("PUZZLE #\(viewModel.puzzle.puzzleNumber)")
//                .font(AppFont.header(24))
//                .foregroundColor(.appTextPrimary)

            Text(viewModel.puzzle.date)
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)
                .tracking(1)
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
            viewModel.useHint()
        } label: {
            Image(systemName: "lightbulb")
                .foregroundColor(.appAccent)
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
