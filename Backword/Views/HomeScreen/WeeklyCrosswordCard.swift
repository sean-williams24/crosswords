//  WeeklyCrosswordCard.swift
//  Backword

import SwiftUI

struct WeeklyCrosswordCard: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @EnvironmentObject var storeService: StoreService
    @ScaledMetric private var iconSize: CGFloat = 10
    @ScaledMetric private var offset: CGFloat = 1
    @ObservedObject var viewModel: HomeViewModel
    @State private var showPaywall = false
    var isProUser: Bool = false

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
//                        HStack(spacing: 6) {
//                            Image(systemName: viewModel.weeklyPuzzleStatus.icon)
//                                .font(.system(size: iconSize))
//                                .foregroundColor(viewModel.weeklyPuzzleStatus.color)
//                                .font(.system(size: 13))
                            Text(viewModel.weeklyPuzzleStatus.label)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .font(AppFont.statNumber(10))
                            .foregroundStyle(viewModel.puzzleStatus.color)
                            .background(content: {
                                RoundedRectangle(cornerRadius: 10)
                                    .shadow(radius: 2)
                            })
//                        }
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
        .padding(24)
        .frame(maxWidth: isIpad ? 400 : .infinity)
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
        .padding(.horizontal, AppLayout.screenPadding)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeService)
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
    WeeklyCrosswordCard(viewModel: HomeViewModel(puzzleService: PuzzleService()))
}
