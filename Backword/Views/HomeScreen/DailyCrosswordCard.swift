//  DailyCrosswordCard.swift

import SwiftUI

enum HomeCardStreakLayout {
    static let streakButtonEdgeInset: CGFloat = 12
}

struct DailyCrosswordCard: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.colorScheme) private var systemColorScheme
    @EnvironmentObject private var statsService: StatsService
    @ObservedObject var viewModel: HomeViewModel
    @ScaledMetric private var iconSize: CGFloat = 10
    var showDailyCrossword: () -> Void

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
            Button {
                showDailyCrossword()
            } label: {
                content
            }
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
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("QUICK CROSSWORD")
                    .font(AppFont.clueLabel(isIpad ? 15 : 11))
                    .foregroundColor(.dailyCardTitle)
                    .tracking(3)
                    .multilineTextAlignment(.center)

                Text("9×9")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)

                if viewModel.state == .loading {
                    ProgressView()
                } else if viewModel.todaysPuzzle == nil {
                    Text("Failed to fetch today's crossword.\nTap here to try again.")
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    StatusLabelView(
                        status: viewModel.puzzleStatus,
                        textStyle: DailyCrosswordCardStatusStyle.textStyle(for: viewModel.puzzleStatus),
                        borderStyle: badgeBorderStyle
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 8)

            bottomStatsView
                .padding(.horizontal, HomeCardStreakLayout.streakButtonEdgeInset)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, minHeight: appLayout.cardHeight)
        .background(cardBackground)
        .environment(\.colorScheme, BackwordAppearance.colorScheme)
        .onAppear {
            viewModel.refreshProgressFromDisk()
        }
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .fill(Color.dailyCardBackground)

            if HomeCardAppearance.shouldBrightenBackground(for: systemColorScheme) {
                RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                    .fill(Color.appTextPrimary.opacity(HomeCardAppearance.lightModeBrightnessOverlayOpacity))
            }
        }
    }

    private var bottomStatsView: some View {
        HStack {
            scoreView
            Spacer(minLength: 2)
            StreakButton(
                streak: statsService.stats.liveCurrentStreak,
                borderStyle: badgeBorderStyle
            )
        }
    }

    @ViewBuilder
    private var scoreView: some View {
        if let score = viewModel.dailyCrosswordScore {
            HStack(spacing: 4) {
                Text("\(score)")
                    .font(AppFont.header(24))
                    .foregroundColor(score == 5 ? .appCorrect : .appAccent)
                Text("/ 5")
                    .font(AppFont.header(12))
                    .foregroundColor(.appTextSecondary)
            }
        }
    }

    private var badgeBorderStyle: HomeCardBadgeBorderStyle {
        BackwordCardAppearance.badgeBorderStyle(for: systemColorScheme)
    }
}

enum DailyCrosswordCardStatusStyle {
    static func textStyle(for status: PuzzleStatus) -> StatusLabelTextStyle {
        if case .inProgress = status {
            return .primary
        }
        return .statusColor
    }
}

#Preview {
    DailyCrosswordCard(viewModel: HomeViewModel(puzzleService: PuzzleService(), storeService: StoreService()), showDailyCrossword: {})
        .environmentObject(StatsService())
        .padding()
}
