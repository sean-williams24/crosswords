import SwiftUI

struct BackwordStatsView: View {
    @Environment(\.dismiss) private var dismiss
    let stats: BackwordStats
    /// When non-nil, the bar for this guess count is highlighted (used on completion)
    var highlightGuessCount: Int? = nil
    /// Injected so previews can compile; unused at runtime.
    @Binding var shouldPop: Bool
    var isCompleted = false
    var completionProgress: BackwordProgress?

    @State private var animatesBars = false

    private var displayState: BackwordCompletionDisplayState {
        BackwordCompletionDisplayState.make(
            progress: completionProgress,
            isCompletion: isCompleted
        )
    }

    var body: some View {
        Group {
            if isCompleted {
                completionBody
            } else {
                statsBody
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                    animatesBars = true
                }
            }
        }
    }

    private var statsBody: some View {
        NavigationStack {
            ZStack {
                AppBackgroundGradient()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        StatsView(stats: stats)
                        distributionSection
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Backword Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        shouldPop = isCompleted
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
        }
    }

    private var completionBody: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    if let title = displayState.title {
                        Text(title)
                            .font(AppFont.header(40))
                            .foregroundColor(titleColor)
                    }
                }

                Group {
                    if displayState.showsStats {
                        completedStatsContent
                    } else if let message = displayState.message {
                        completionMessage(message)
                    }
                }

                Spacer()

                Button {
                    dismiss()
                    shouldPop = true
                } label: {
                    Text("HOME")
                        .font(AppFont.body())
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.bottom, 32)
            }
        }
    }

    private var titleColor: Color {
        switch displayState.titleStyle {
        case .solved:
            return .appTextHeading
        case .finished:
            return .appCorrect
        }
    }

    private func completionMessage(_ message: String) -> some View {
        Text(message)
            .font(AppFont.body())
            .foregroundColor(.appTextSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var completedStatsContent: some View {
        VStack(spacing: 28) {
            StatsView(stats: stats)
            distributionSection
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    // MARK: - Distribution

    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GUESS DISTRIBUTION")
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)
                .tracking(2)
                .lineLimit(2)
                .minimumScaleFactor(0.5)

            if stats.gamesWon == 0 || stats.guessCounts.isEmpty {
                Text("No wins yet — keep playing!")
                    .font(AppFont.body(14))
                    .foregroundColor(.appTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { guessNum in
                        distributionRow(guessNum: guessNum)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .strokeBorder(.clear)
        )
    }

    @ScaledMetric private var numberIconFrame: CGFloat = 16

    private func distributionRow(guessNum: Int) -> some View {
        let count = stats.count(forGuess: guessNum)
        let maxCount = max(stats.maxGuessCount, 1)
        let fraction = CGFloat(count) / CGFloat(maxCount)
        let isHighlighted = highlightGuessCount == guessNum
        let barColor: Color = isHighlighted ? .appCorrect : .appAccent

        return HStack(spacing: 10) {
            Text("\(guessNum)")
                .font(AppFont.clueLabel(14))
                .foregroundColor(.appTextSecondary)
                .frame(width: numberIconFrame, alignment: .center)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.appGridLine.opacity(0.4), lineWidth: 1)
                        )

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: isHighlighted
                                    ? [Color.appCorrect.opacity(0.8), Color.appCorrect]
                                    : [barColor.opacity(0.7), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: animatesBars ? max(geo.size.width * fraction, count > 0 ? 36 : 0) : 0)
                }
            }
            .frame(height: 32)

            Text("\(count)")
                .font(AppFont.clueLabel(13))
                .foregroundColor(isHighlighted ? .appCorrect : .appTextSecondary)
                .frame(width: numberIconFrame, alignment: .center)
                .scaleEffect(isHighlighted ? 1.1 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.4), value: animatesBars)
        }
        .frame(height: 32)
    }
}

// MARK: - Preview

#Preview("Has data") {
    var s = BackwordStats()
    s.record(guessCount: 1, date: "2026-04-18")
    s.record(guessCount: 2, date: "2026-04-19")
    s.record(guessCount: 2, date: "2026-04-20")
    s.record(guessCount: 3, date: "2026-04-21")
    s.record(guessCount: nil, date: "2026-04-22")
    return BackwordStatsView(stats: s, highlightGuessCount: 2, shouldPop: .constant(false))
        .preferredColorScheme(.dark)
}

#Preview("Empty") {
    BackwordStatsView(stats: BackwordStats(), shouldPop: .constant(false))
        .preferredColorScheme(.dark)
}
