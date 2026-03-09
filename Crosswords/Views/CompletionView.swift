import SwiftUI

struct CompletionView: View {
    @ObservedObject var viewModel: GameViewModel
    @EnvironmentObject var statsService: StatsService
    @Environment(\.dismiss) private var dismiss

    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Celebration header
                VStack(spacing: 8) {
                    Text("Solved!")
                        .font(AppFont.header(40))
                        .foregroundColor(.appTextPrimary)

                    Text("PUZZLE #\(viewModel.puzzle.puzzleNumber)")
                        .font(AppFont.clueLabel(14))
                        .foregroundColor(.appTextSecondary)
                        .tracking(3)
                }
                .scaleEffect(showContent ? 1.0 : 0.6)
                .opacity(showContent ? 1.0 : 0.0)

                // Stats card
                HStack(spacing: 24) {
                    statItem(
                        value: viewModel.progress.formattedTime,
                        label: "TIME"
                    )
                    statDivider
                    statItem(
                        value: "\(viewModel.progress.hintsUsed)",
                        label: "HINTS"
                    )
                    statDivider
                    statItem(
                        value: "\(statsService.stats.currentStreak)",
                        label: "STREAK"
                    )
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(Color.appSurface)
                .cornerRadius(AppLayout.cardCornerRadius)
                .padding(.horizontal, AppLayout.screenPadding)
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 20)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    ShareLink(item: shareText) {
                        Label("Share Result", systemImage: "square.and.arrow.up")
                            .font(AppFont.body())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.appAccent)
                            .cornerRadius(AppLayout.cardCornerRadius)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(AppFont.body())
                            .foregroundColor(.appTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.bottom, 32)
                .opacity(showContent ? 1.0 : 0.0)
            }
        }
        .onAppear {
            statsService.recordCompletion(
                puzzleId: viewModel.puzzle.id,
                timeSeconds: Int(viewModel.progress.elapsedTime),
                hintsUsed: viewModel.progress.hintsUsed
            )

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showContent = true
            }
        }
        .interactiveDismissDisabled(false)
    }

    // MARK: - Components

    @ViewBuilder
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFont.header(28))
                .foregroundColor(.appTextPrimary)
            Text(label)
                .font(AppFont.clueLabel(10))
                .foregroundColor(.appTextSecondary)
                .tracking(2)
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.appGridLine)
            .frame(width: 1, height: 40)
    }

    // MARK: - Share

    private var shareText: String {
        let streak = statsService.stats.currentStreak
        let hints = viewModel.progress.hintsUsed
        let time = viewModel.progress.formattedTime
        let number = viewModel.puzzle.puzzleNumber

        var text = "Crosswords #\(number) 🟩\n"
        text += "⏱ \(time)"
        if streak > 1 { text += " | 🔥 \(streak)-day streak" }
        if hints == 0 { text += " | 💡 No hints" }
        else { text += " | 💡 \(hints) hint\(hints == 1 ? "" : "s")" }
        return text
    }
}
