//  WeeklyCrosswordCard.swift
//  Backword

import SwiftUI

struct WeeklyCrosswordCard: View {
    @EnvironmentObject var storeService: StoreService
    @ScaledMetric private var iconSize: CGFloat = 10
    @ScaledMetric private var offset: CGFloat = 1
    @ObservedObject var viewModel: HomeViewModel
    @State private var showPaywall = false
    var isProUser: Bool = false

    var body: some View {
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

    private var content: some View {
        VStack(spacing: 12) {
            ViewThatFits {
                horizontalTitleContent
                verticalTitleContent
            }

            if viewModel.isLoading && viewModel.weeklyPuzzle == nil {
                ProgressView()
            } else {
                Text("13×13")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)

                if isProUser {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.weeklyPuzzleStatus.icon)
                            .foregroundColor(viewModel.weeklyPuzzleStatus.color)
                            .font(.system(size: 13))
                        Text(viewModel.weeklyPuzzleStatus.label)
                            .font(AppFont.caption())
                            .foregroundColor(.appTextSecondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("Pro Only")
                            .font(AppFont.caption())
                            .foregroundColor(.appAccent)
                        Image(systemName: "lock.fill")
                            .font(.system(size: iconSize))
                            .font(.system(size: 12))
                            .foregroundColor(.appAccent)
                            .offset(y: offset)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
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
                .font(AppFont.clueLabel(11))
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
