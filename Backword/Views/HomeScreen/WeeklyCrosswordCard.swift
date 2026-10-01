//  WeeklyCrosswordCard.swift
//  Backword

import SwiftUI

struct WeeklyCrosswordCard: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var statsService: StatsService
    @EnvironmentObject var storeService: StoreService
    @ScaledMetric private var iconSize: CGFloat = 10
    @ScaledMetric private var offset: CGFloat = 1
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
        Group {
            if AnagramHomeCardLayout.usesStackedLayout(for: dynamicTypeSize) {
                VStack(alignment: .leading, spacing: AnagramHomeCardLayout.columnSpacing) {
                    identityView
                    detailsView
                }
            } else {
                HStack(alignment: .top, spacing: AnagramHomeCardLayout.columnSpacing) {
                    identityView
                    detailsView
                }
            }
        }
        .padding(.horizontal, AnagramHomeCardLayout.horizontalPadding)
        .padding(.vertical, AnagramHomeCardLayout.verticalPadding)
        .frame(maxWidth: .infinity, minHeight: appLayout.cardHeight)
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
        }
        .onAppear {
            viewModel.refreshProgressFromDisk()
        }
    }

    private var identityView: some View {
        VStack(alignment: .leading, spacing: AnagramHomeCardLayout.identitySpacing) {
            Text("PRO \nCROSSWORD")
                .font(AppFont.clueLabel(appLayout.isiPad ? 20 : 16))
                .foregroundStyle(proGradient)
                .tracking(3)
                .lineLimit(2)
                .minimumScaleFactor(0.35)
                .multilineTextAlignment(.leading)
                .accessibilityLabel("Pro Crossword")

            Text("13×13")
                .font(AppFont.caption())
                .foregroundColor(.appTextSecondary)

            if let issueNumber = viewModel.weeklyPuzzle?.puzzleNumber {
                HomeCardIssueNumber(issueNumber: issueNumber, color: .solvedGold)
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var detailsView: some View {
        VStack(alignment: .trailing, spacing: AnagramHomeCardLayout.contentSpacing) {
            Spacer(minLength: AnagramHomeCardLayout.minimumContentSpacing)

            if viewModel.state == .loading {
                ProgressView()
            } else if isProUser {
                if viewModel.weeklyPuzzle == nil {
                    Text("Failed to fetch today's crossword.\nTap here to try again.")
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.trailing)
                } else {
                    StatusLabelView(
                        status: viewModel.weeklyPuzzleStatus,
                        borderStyle: badgeBorderStyle
                    )
                }
            } else {
                proOnlyLabel
            }

            bottomStatsView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private var proOnlyLabel: some View {
        HStack(spacing: 6) {
            Text("Pro Only")
                .font(AppFont.caption())
                .foregroundColor(.appAccent)
            Image(systemName: "lock.fill")
                .font(.system(size: iconSize))
                .foregroundColor(.appAccent)
                .offset(y: offset)
        }
    }

    private var bottomStatsView: some View {
        HStack(spacing: AnagramHomeCardLayout.statsSpacing) {
            scoreView
            StreakButton(
                streak: statsService.stats.currentStreak(isWeekly: true),
                borderStyle: badgeBorderStyle
            )
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
