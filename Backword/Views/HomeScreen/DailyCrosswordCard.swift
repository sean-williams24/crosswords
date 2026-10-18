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
    var showDailyCrossword: () -> Void

    private var appLayout: AppLayout {
        AppLayout(sizeClass: sizeClass)
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
        HomeGameCardContent(minimumHeight: appLayout.cardHeight, spacing: .zero) {
            identityView
        } details: {
            detailsView
        } header: {
            HomeGameCardHeader(spacing: AnagramHomeCardLayout.statsSpacing) {
                EmptyView()
            } streak: {
                StreakButton(streak: statsService.stats.liveCurrentStreak, borderStyle: badgeBorderStyle)
            }
        }
        .background(
            cardBackground.environment(
                \.colorScheme,
                HomeCardAppearance.backgroundColorScheme(for: systemColorScheme)
            )
        )
        .environment(\.colorScheme, BackwordAppearance.colorScheme)
        .onAppear {
            viewModel.refreshProgressFromDisk()
        }
    }

    private var identityView: some View {
        VStack(spacing: AnagramHomeCardLayout.identitySpacing) {
            Text("QUICK\nCROSSWORD")
                .font(AppFont.clueLabel(appLayout.isiPad ? 20 : 16))
                .foregroundColor(.dailyCardTitle)
                .tracking(3)
                .padding(.trailing, -3)
                .lineLimit(2)
                .minimumScaleFactor(0.35)
                .multilineTextAlignment(.center)
            Text("9×9")
                .font(AppFont.caption())
                .foregroundColor(.dailyCardDescription)
        }
    }

    @ViewBuilder
    private var issueLabel: some View {
        if let issueNumber = viewModel.todaysPuzzle?.puzzleNumber {
            HomeCardIssueNumber(issueNumber: issueNumber)
        }
    }

    private var detailsView: some View {
        HomeGameCardFooter(spacing: AnagramHomeCardLayout.statsSpacing) {
            scoreView
        } status: {
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
        } issue: {
            issueLabel
        }
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .fill(Color.dailyCardBackground)

            if HomeCardAppearance.shouldBrightenBackground(for: systemColorScheme) {
                RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                    .fill(Color.homeCardBrightnessOverlay.opacity(HomeCardAppearance.lightModeBrightnessOverlayOpacity))
            }
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
