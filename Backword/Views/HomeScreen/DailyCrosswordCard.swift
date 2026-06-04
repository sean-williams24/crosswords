//  DailyCrosswordCard.swift

import SwiftUI

struct DailyCrosswordCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var sizeClass
    @EnvironmentObject private var statsService: StatsService
    @ObservedObject var viewModel: HomeViewModel
    @ScaledMetric private var iconSize: CGFloat = 10
    @State private var showStreakPopup = false

    private var appLayout: AppLayout {
        AppLayout(sizeClass: sizeClass)
    }

    private var isIpad: Bool {
        sizeClass == .regular
    }

    var body: some View {
        switch viewModel.state {
        case .failed:
            failedButton
        case .loading:
            content
        case .success:
            NavigationLink(value: "puzzle") {
                content
            }
            .buttonStyle(.plain)
        }
    }

    private var failedButton: some View {
        Button {
            Task {
                await viewModel.loadTodaysPuzzle()
            }
        } label: {
            content
        }
    }

    private var content: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                Text("CROSSWORD")
                    .font(AppFont.clueLabel(isIpad ? 15 : 11))
                    .foregroundColor(.dailyCardTitle)
                    .tracking(3)
                    .multilineTextAlignment(.center)

                Text("9×9")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)

                if let score = viewModel.dailyCrosswordScore {
                    HStack(spacing: 4) {
                        Text("\(score)")
                            .font(AppFont.header(28))
                            .foregroundColor(score == 5 ? .appCorrect : .appAccent)
                        Text("/ 5")
                            .font(AppFont.header(16))
                            .foregroundColor(.appTextSecondary)
                    }
                }

                if viewModel.state == .loading {
                    ProgressView()
                } else if viewModel.todaysPuzzle == nil {
                    Text("Failed to fetch today's crossword.\nTap here to try again.")
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                } else {
                    StatusLabelView(status: viewModel.puzzleStatus)
                }
                if dynamicTypeSize >= .accessibility1 {
                    streakButton
                }
            }
            if dynamicTypeSize < .accessibility1 {
                streakButton
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: appLayout.cardHeight)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .fill(Color.dailyCardBackground)
        )
    }

    @ViewBuilder
    private var streakButton: some View {
        if statsService.stats.liveCurrentStreak > 0 {
            Button {
                showStreakPopup.toggle()
                if showStreakPopup {
                    Task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStreakPopup = false
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("\(statsService.stats.liveCurrentStreak)")
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appTextPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appSurface.opacity(0.5))
                .cornerRadius(14)
                .padding(.trailing, 12)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .buttonStyle(.plain)
            .overlay(alignment: .top) {
                if showStreakPopup {
                    Text("\(statsService.stats.liveCurrentStreak)-day streak")
                        .fixedSize()
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appTextPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.appSurface)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                        .offset(y: dynamicTypeSize >= .accessibility1 ? -60 : 0)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showStreakPopup)
        }
    }
}

#Preview {
    DailyCrosswordCard(viewModel: HomeViewModel(puzzleService: PuzzleService()))
        .environmentObject(StatsService())
        .padding()
}
