import Foundation
import LinkPresentation
import SwiftUI
import UIKit

/// A spoiler-safe, portable summary of a completed puzzle.
///
/// Keep this model limited to aggregate game data. In particular it must never
/// include a Backword answer or guess, crossword clue, or grid cell content.
struct PuzzleShareResult: Equatable {
    enum Game: String, Equatable {
        case backword
        case dailyCrossword = "daily_crossword"
        case weeklyCrossword = "weekly_crossword"

        var displayName: String {
            switch self {
            case .backword: "Backword"
            case .dailyCrossword: "Quick Crossword"
            case .weeklyCrossword: "Pro Crossword"
            }
        }

        var analyticsGame: BackwordAnalyticsEvent.Game {
            switch self {
            case .backword: .backword
            case .dailyCrossword: .dailyCrossword
            case .weeklyCrossword: .weeklyCrossword
            }
        }

        var pathPrefix: String {
            switch self {
            case .backword: "/backword/"
            case .dailyCrossword: "/crossword/"
            case .weeklyCrossword: "/weekly-crossword/"
            }
        }
    }

    struct Stat: Equatable {
        let label: String
        let value: String
    }

    let game: Game
    let issueNumber: Int?
    let date: String
    let outcome: String
    let score: Int
    let streak: Int
    let totalGamesSolved: Int
    let ratingTier: String
    let ratingPoints: Int
    let ratingMaxPoints: Int
    let primaryStat: Stat
    let timeStat: Stat?

    var issueLabel: String {
        guard let issueNumber else { return game.displayName }
        return "\(game.displayName) #\(issueNumber)"
    }

    var scoreLabel: String {
        "\(score) \(score == 1 ? "PT" : "PTS")"
    }

    var shareURL: URL {
        var components = URLComponents(string: "https://www.playbackword.com\(game.pathPrefix)\(date)")!
        components.queryItems = [
            URLQueryItem(name: "utm_source", value: "share"),
            URLQueryItem(name: "utm_medium", value: "social"),
            URLQueryItem(name: "utm_campaign", value: "completed_puzzle")
        ]
        return components.url!
    }

    var caption: String {
        let verb = outcome == "SOLVED" ? "I solved" : "I completed"
        var values = [
            "\(score) \(score == 1 ? "pt" : "pts")",
            primaryStat.value,
            "\(streak) \(streak == 1 ? "day" : "days") streak",
            "\(ratingTier) · \(ratingPoints)/\(ratingMaxPoints) pts"
        ]
        if let timeStat {
            values.insert(timeStat.value, at: 2)
        }
        return "\(verb) \(issueLabel)\n\(values.joined(separator: " · "))\nPlay: \(shareURL.absoluteString)"
    }

    static func backword(
        progress: BackwordProgress,
        word: BackwordWord,
        stats: BackwordStats,
        rating: OverallRating,
        isPro: Bool
    ) -> PuzzleShareResult {
        PuzzleShareResult(
            game: .backword,
            issueNumber: word.puzzleNumber,
            date: progress.date,
            outcome: progress.isWon ? "SOLVED" : "COMPLETED",
            score: rating.score(for: .backword, date: progress.date),
            streak: stats.liveCurrentStreak,
            totalGamesSolved: stats.gamesWon,
            ratingTier: rating.tier(isPro: isPro).displayName,
            ratingPoints: rating.totalPoints(isPro: isPro),
            ratingMaxPoints: rating.maxPoints(isPro: isPro),
            primaryStat: Stat(label: "ATTEMPTS", value: "\(progress.guesses.count) / 5"),
            timeStat: Stat(label: "COMPLETED", value: completedTime(progress.completedAt))
        )
    }

    static func crossword(
        puzzle: Puzzle,
        progress: UserProgress,
        stats: UserStats,
        rating: OverallRating,
        isPro: Bool
    ) -> PuzzleShareResult {
        let game: Game = puzzle.size > 12 ? .weeklyCrossword : .dailyCrossword
        let category: RatingGameCategory = puzzle.size > 12 ? .weeklyCrossword : .dailyCrossword
        let streak = stats.currentStreak(isWeekly: puzzle.size > 12)
        return PuzzleShareResult(
            game: game,
            issueNumber: puzzle.puzzleNumber,
            date: puzzle.date,
            outcome: "SOLVED",
            score: rating.score(for: category, date: puzzle.date),
            streak: streak,
            totalGamesSolved: stats.totalCompleted(isWeekly: puzzle.size > 12),
            ratingTier: rating.tier(isPro: isPro).displayName,
            ratingPoints: rating.totalPoints(isPro: isPro),
            ratingMaxPoints: rating.maxPoints(isPro: isPro),
            primaryStat: Stat(label: "SOLVE TIME", value: Int(progress.elapsedTime).formattedTimeHHMMSS),
            timeStat: nil
        )
    }

    private static func completedTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// A square, rendered result card sized for social-media previews. It
/// deliberately contains only the data in `PuzzleShareResult`, so it cannot
/// reveal the puzzle's contents.
private struct PuzzleResultShareCard: View {
    let result: PuzzleShareResult

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.issueLabel)
                        .font(AppFont.header(38))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(result.outcome)
                        .font(AppFont.clueLabel(11))
                        .foregroundColor(.solvedGold)
                        .tracking(2)
                }

                Spacer(minLength: 12)

                Image("BackWordLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 70)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                spacing: 16
            ) {
                statTile(label: "TODAY'S SCORE", value: result.scoreLabel)
                statTile(label: result.primaryStat.label, value: result.primaryStat.value)
                statTile(label: "CURRENT RATING", value: "\(result.ratingTier.uppercased())\n \(result.ratingPoints)/\(result.ratingMaxPoints) PTS")
                statTile(label: "CURRENT STREAK", value: "\(result.streak) \(result.streak == 1 ? "DAY" : "DAYS")")
                statTile(label: timeStat.label, value: timeStat.value)
            }

            HStack {
                Spacer()
                Text("playbackword.com")
                    .font(AppFont.clueLabel(20))
                    .foregroundColor(.solvedGold)
                    .tracking(1.5)
                    .padding(.trailing, 3)
            }
        }
        .padding(42)
        .frame(width: 600, height: 600, alignment: .leading)
        .background(cardBackground)
//        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(cardBorder)
        .preferredColorScheme(.dark)
    }

    /// Use the same dark-mode surface as the corresponding iOS Home card.
    @ViewBuilder
    private var cardBackground: some View {
        switch result.game {
        case .backword:
            ZStack {
                Color.appCrosswordBackground
                Color.backwordBackground
            }
        case .dailyCrossword:
            Color.dailyCardBackground
        case .weeklyCrossword:
            Color.appSurface.overlay(AnyView(proGradient).opacity(0.02))
        }
    }

    @ViewBuilder
    private var cardBorder: some View {
        if result.game == .weeklyCrossword {
            RoundedRectangle(cornerRadius: 0)
                .stroke(proGradient, lineWidth: 1.5)
        }
    }

    private var proGradient: LinearGradient {
        AppGradient.pro
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(AppFont.clueLabel(10))
                .foregroundColor(.appTextSecondary)
                .tracking(1.5)
            Text(value)
                .font(AppFont.header(18))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var timeStat: PuzzleShareResult.Stat {
        result.timeStat ?? PuzzleShareResult.Stat(label: "TOTAL SOLVED", value: "\(result.totalGamesSolved)")
    }
}

struct PuzzleResultShareButton: View {
    let result: PuzzleShareResult
    var compact = false
    @State private var presentsShareSheet = false

    var body: some View {
        Button {
            presentsShareSheet = true
        } label: {
            Label(compact ? "Share" : "Share result", systemImage: "square.and.arrow.up")
                .font(AppFont.body(16))
                .foregroundColor(.appTextPrimary)
                .frame(maxWidth: compact ? nil : .infinity)
                .padding(.horizontal, compact ? 14 : 0)
                .padding(.vertical, compact ? 10 : 14)
                .background(compact ? Color.appAccent : Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
                .shadow(
                    color: compact ? Color.appTextPrimary.opacity(0.16) : .clear,
                    radius: compact ? 6 : 0,
                    x: 0,
                    y: compact ? 3 : 0
                )
        }
        .accessibilityHint("Opens the system share sheet")
        .sheet(isPresented: $presentsShareSheet) {
            PuzzleResultActivitySheet(result: result)
                .ignoresSafeArea()
        }
    }
}

private struct PuzzleResultActivitySheet: UIViewControllerRepresentable {
    let result: PuzzleShareResult

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let item = PuzzleResultActivityItem(result: result)
        let controller = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            guard completed else { return }
            BackwordAnalyticsService.shared.log(
                .resultShared(
                    game: result.game.analyticsGame,
                    delivery: .forActivity(activityType)
                )
            )
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class PuzzleResultActivityItem: NSObject, UIActivityItemSource {
    private let result: PuzzleShareResult
    private let cardImage: UIImage

    @MainActor
    init(result: PuzzleShareResult) {
        self.result = result
        let renderer = ImageRenderer(content: PuzzleResultShareCard(result: result))
        renderer.scale = UIScreen.main.scale
        self.cardImage = renderer.uiImage ?? UIImage()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        cardImage
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        // iOS Copy otherwise receives an image and a separate text item, which
        // pastes as two results. Give it one spoiler-safe caption and deep link.
        if activityType == .copyToPasteboard {
            return result.caption
        }
        return cardImage
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        result.issueLabel
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        activityType == .copyToPasteboard ? "public.plain-text" : "public.png"
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = result.issueLabel
        metadata.originalURL = result.shareURL
        metadata.url = result.shareURL
        metadata.imageProvider = NSItemProvider(object: cardImage)
        return metadata
    }
}

// MARK: - Previews

private extension PuzzleShareResult {
    static let previewBackwordSolved = PuzzleShareResult(
        game: .backword,
        issueNumber: 173,
        date: "2026-09-20",
        outcome: "SOLVED",
        score: 5,
        streak: 12,
        totalGamesSolved: 27,
        ratingTier: "Linguist",
        ratingPoints: 68,
        ratingMaxPoints: 140,
        primaryStat: .init(label: "ATTEMPTS", value: "1 / 5"),
        timeStat: .init(label: "COMPLETED", value: "2:30 PM")
    )

    static let previewBackwordCompleted = PuzzleShareResult(
        game: .backword,
        issueNumber: 173,
        date: "2026-09-20",
        outcome: "COMPLETED",
        score: 1,
        streak: 0,
        totalGamesSolved: 18,
        ratingTier: "Wordsmith",
        ratingPoints: 42,
        ratingMaxPoints: 140,
        primaryStat: .init(label: "ATTEMPTS", value: "5 / 5"),
        timeStat: .init(label: "COMPLETED", value: "4:10 PM")
    )

    static let previewDailyCrosswordSolved = PuzzleShareResult(
        game: .dailyCrossword,
        issueNumber: 84,
        date: "2026-09-20",
        outcome: "SOLVED",
        score: 4,
        streak: 6,
        totalGamesSolved: 31,
        ratingTier: "Linguist",
        ratingPoints: 68,
        ratingMaxPoints: 140,
        primaryStat: .init(label: "SOLVE TIME", value: "04:38"),
        timeStat: nil
    )

    static let previewWeeklyCrosswordSolved = PuzzleShareResult(
        game: .weeklyCrossword,
        issueNumber: 12,
        date: "2026-09-14",
        outcome: "SOLVED",
        score: 5,
        streak: 3,
        totalGamesSolved: 12,
        ratingTier: "Cruciverbalist",
        ratingPoints: 122,
        ratingMaxPoints: 210,
        primaryStat: .init(label: "SOLVE TIME", value: "12:47"),
        timeStat: nil
    )
}

/// Shows the 600-point export card at a phone-friendly scale in Xcode without
/// changing the dimensions used by `ImageRenderer` for the shared image.
private struct PuzzleResultShareCardPreview: View {
    let result: PuzzleShareResult

    var body: some View {
        PuzzleResultShareCard(result: result)
            .scaleEffect(0.55)
            .frame(width: 330, height: 330)
            .padding(12)
            .background(Color.appBackground)
    }
}

#Preview("Backword — solved") {
    PuzzleResultShareCardPreview(result: .previewBackwordSolved)
}

#Preview("Backword — completed") {
    PuzzleResultShareCardPreview(result: .previewBackwordCompleted)
}

#Preview("Quick Crossword — solved") {
    PuzzleResultShareCardPreview(result: .previewDailyCrosswordSolved)
}

#Preview("Pro Crossword — solved") {
    PuzzleResultShareCardPreview(result: .previewWeeklyCrosswordSolved)
}
