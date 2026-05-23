import SwiftUI

struct BackwordStatsView: View {
    let stats: BackwordStats
    /// When non-nil, the bar for this guess count is highlighted (used on completion)
    var highlightGuessCount: Int? = nil
    /// Injected so previews can compile; unused at runtime.
    var onDismiss: (() -> Void)? = nil

    @State private var animatesBars = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.appAccent.opacity(0.10), Color.appBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

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
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
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
                .strokeBorder(Color.appAccent.opacity(0.2), lineWidth: 1)
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

// MARK: - Convenience font overload

//private extension AppFont {
//    static func statNumber(_ size: CGFloat = 32) -> Font {
//        AppFont.header(size)
//    }
//}

// MARK: - Preview

#Preview("Has data") {
    var s = BackwordStats()
    s.record(guessCount: 1, date: "2026-04-18")
    s.record(guessCount: 2, date: "2026-04-19")
    s.record(guessCount: 2, date: "2026-04-20")
    s.record(guessCount: 3, date: "2026-04-21")
    s.record(guessCount: nil, date: "2026-04-22")
    return BackwordStatsView(stats: s, highlightGuessCount: 2) {}
        .preferredColorScheme(.dark)
}

#Preview("Empty") {
    BackwordStatsView(stats: BackwordStats()) {}
        .preferredColorScheme(.dark)
}
