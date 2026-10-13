//  WeeklyCrosswordCard.swift
//  Backword

import SwiftUI

struct WeeklyCrosswordCard: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.colorScheme) private var systemColorScheme
    @EnvironmentObject private var statsService: StatsService
    @EnvironmentObject var storeService: StoreService
    @ObservedObject var viewModel: HomeViewModel
    @State private var showPaywall = false
    var isProUser: Bool = false

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
            if isProUser {
                NavigationLink(value: "weekly") {
                    content
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    content
                }
                .buttonStyle(.plain)
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
                StreakButton(streak: statsService.stats.currentStreak(isWeekly: true), borderStyle: badgeBorderStyle)
            }
        }
        .background(
            Color.appSurface.overlay(
                proGradient.opacity(0.02)
            )
        )
        .cornerRadius(AppLayout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .stroke(proGradient, lineWidth: 1.5)
        )
        .environment(\.colorScheme, WeeklyCrosswordCardAppearance.colorScheme)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
        }
        .onAppear {
            viewModel.refreshProgressFromDisk()
        }
    }

    private var identityView: some View {
        VStack(spacing: AnagramHomeCardLayout.identitySpacing) {
            Text("PRO\nCROSSWORD")
                .font(AppFont.clueLabel(appLayout.isiPad ? 20 : 16))
                .foregroundStyle(proGradient)
                .tracking(3)
                .padding(.trailing, -3)
                .lineLimit(2)
                .minimumScaleFactor(0.35)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Pro Crossword")
            Text("13×13")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)
        }
    }

    @ViewBuilder
    private var issueLabel: some View {
        if let issueNumber = viewModel.weeklyPuzzle?.puzzleNumber {
            HomeCardIssueNumber(issueNumber: issueNumber, color: .solvedGold)
        }
    }

    private var detailsView: some View {
        HomeGameCardFooter(spacing: AnagramHomeCardLayout.statsSpacing) {
            scoreView
        } status: {
            if viewModel.state == .loading {
                ProgressView()
            } else if isProUser {
                if viewModel.weeklyPuzzle == nil {
                    Text("Failed to fetch today's crossword.\nTap here to try again.")
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    StatusLabelView(
                        status: viewModel.weeklyPuzzleStatus,
                        borderStyle: badgeBorderStyle
                    )
                }
            } else {
                ProOnlyBadge()
            }
        } issue: {
            issueLabel
        }
    }

    @ViewBuilder
    private var scoreView: some View {
        if let score = viewModel.weeklyCrosswordScore {
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

    private var proGradient: LinearGradient {
        AppGradient.pro
    }
}

#Preview {
    WeeklyCrosswordCard(viewModel: HomeViewModel(puzzleService: PuzzleService(), storeService: StoreService()))
        .environmentObject(StatsService())
        .environmentObject(StoreService())
}
