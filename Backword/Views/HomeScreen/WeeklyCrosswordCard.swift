//  WeeklyCrosswordCard.swift
//  Backword

import SwiftUI

struct WeeklyCrosswordCard: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @EnvironmentObject private var statsService: StatsService
    @EnvironmentObject var storeService: StoreService
    @ScaledMetric private var iconSize: CGFloat = 10
    @ScaledMetric private var offset: CGFloat = 1
    @ObservedObject var viewModel: HomeViewModel
    @State private var showPaywall = false
    var isProUser: Bool = false

    private var isIpad: Bool {
        sizeClass == .regular
    }

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
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                ViewThatFits {
                    horizontalTitleContent
                    verticalTitleContent
                }

                Text("13×13")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)

                if viewModel.state == .loading {
                    ProgressView()
                } else {
                    if isProUser {
                        if viewModel.weeklyPuzzle == nil {
                            Text("Failed to fetch today's crossword.\nTap here to try again.")
                                .font(AppFont.caption())
                                .foregroundColor(.appTextSecondary)
                        } else {
                            StatusLabelView(status: viewModel.weeklyPuzzleStatus)
                        }
                    } else {
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
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 8)

            bottomStatsView
                .padding(.horizontal, HomeCardStreakLayout.streakButtonEdgeInset)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: isIpad ? 400 : .infinity, minHeight: appLayout.cardHeight)
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

    private var bottomStatsView: some View {
        HStack {
            scoreView
            Spacer(minLength: 2)
            StreakButton(streak: statsService.stats.currentStreak(isWeekly: true))
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

    private var horizontalTitleContent: some View {
        HStack(spacing: 6) {
            crown
            Text("PRO CROSSWORD")
                .font(AppFont.clueLabel(isIpad ? 15 : 11))
                .foregroundStyle(proGradient)
                .tracking(3)
                .multilineTextAlignment(.center)
            crown
        }
    }

    private var verticalTitleContent: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack {
                crown
                Text("PRO")
                    .font(AppFont.clueLabel(11))
                    .foregroundStyle(proGradient)
                    .tracking(3)
                    .multilineTextAlignment(.center)
                crown
            }
            Text("CROSSWORD")
                .font(AppFont.clueLabel(11))
                .foregroundStyle(proGradient)
                .tracking(3)
                .multilineTextAlignment(.center)
        }
    }

    private var crown: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: iconSize))
            .foregroundStyle(proGradient)
    }

    private var proGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.85, green: 0.65, blue: 0.25),
                Color(red: 0.78, green: 0.52, blue: 0.20),
                Color(red: 0.85, green: 0.65, blue: 0.25)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    WeeklyCrosswordCard(viewModel: HomeViewModel(puzzleService: PuzzleService(), storeService: StoreService()))
        .environmentObject(StatsService())
        .environmentObject(StoreService())
}
