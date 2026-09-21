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

        /// Backword and Pro Crossword cards retain their dark visual identities
        /// independently of the device appearance used to create the share image.
        var usesDarkShareCardAppearance: Bool {
            self == .backword || self == .weeklyCrossword
        }

        /// The lavender Backword card needs a darker label treatment than the
        /// neutral share-card surfaces to meet the same visual contrast.
        var usesHighContrastShareCardStatLabels: Bool {
            self == .backword
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
        "\(score) \(score == 1 ? "pt" : "pts")"
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
            primaryStat: Stat(label: "ATTEMPTS", value: "\(progress.guesses.count)/5"),
            timeStat: Stat(label: "COMPLETED AT", value: completedTime(progress.completedAt))
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

    static func completedTime(_ date: Date?, timeZone: TimeZone = .current) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

/// Fixed dimensions for the social card shared by iOS and the web app.
///
/// iOS lays the card out at a phone-friendly 540 points, then renders it at 2x
/// to keep the shared PNG at 1080px square. Social apps can safely downsize
/// that source without introducing the pixelation a 500px source produces.
enum PuzzleResultShareCardLayout {
    static let designCanvasSize: CGFloat = 1080
    static let canvasSize: CGFloat = 540
    static let exportPixelSize: CGFloat = 1080
    static let renderScale: CGFloat = exportPixelSize / canvasSize

    static func scaled(_ designValue: CGFloat) -> CGFloat {
        designValue * canvasSize / designCanvasSize
    }

    static let cornerRadius = scaled(48)
    static let statWidth = scaled(452)
}

/// A square, rendered result card sized for social-media previews. It
/// deliberately contains only the data in `PuzzleShareResult`, so it cannot
/// reveal the puzzle's contents.
private struct PuzzleResultShareCard: View {
    let result: PuzzleShareResult

    @ViewBuilder
    var body: some View {
        if result.game.usesDarkShareCardAppearance {
            cardContent
                .environment(\.colorScheme, .dark)
        } else {
            cardContent
        }
    }

    private var cardContent: some View {
        ZStack(alignment: .topLeading) {
            cardBackground

            Text(result.issueLabel)
                .font(AppFont.shareCardTitle(titleFontSize))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(58.0 / 86.0)
                .frame(width: scaled(640), alignment: .leading)
                .offset(x: scaled(64), y: scaled(70))

            Text(result.outcome)
                .font(AppFont.shareCardTitle(scaled(27)))
                .foregroundColor(.solvedGold)
                .tracking(scaled(4))
                .offset(x: scaled(64), y: scaled(178))

            Image("BackWordLogoShare")
                .resizable()
                .scaledToFit()
                .frame(width: scaled(252), height: scaled(126))
                .offset(x: scaled(752), y: scaled(76))

            statTile(label: "TODAY'S SCORE", value: result.scoreLabel, height: scaled(200))
                .offset(x: scaled(64), y: scaled(250))
            statTile(label: result.primaryStat.label, value: shareCardValue(result.primaryStat.value), height: scaled(200))
                .offset(x: scaled(564), y: scaled(250))
            ratingStatTile
                .offset(x: scaled(64), y: scaled(480))
            statTile(label: "CURRENT STREAK", value: streakValue, height: scaled(250))
                .offset(x: scaled(564), y: scaled(480))
            statTile(label: timeStat.label, value: shareCardValue(timeStat.value), height: scaled(190))
                .offset(x: scaled(64), y: scaled(760))

            Text("playbackword.com")
                .font(AppFont.shareCardTitle(scaled(55)))
                .foregroundColor(result.game == .weeklyCrossword ? .solvedGold : .appGridLine)
                .tracking(scaled(3))
                .frame(width: scaled(952), alignment: .trailing)
                .offset(x: scaled(64), y: scaled(966))
        }
        .frame(
            width: PuzzleResultShareCardLayout.canvasSize,
            height: PuzzleResultShareCardLayout.canvasSize,
            alignment: .topLeading
        )
        .background(cardBackground)
    }

    /// These fixed colours and dimensions are shared with the web-card renderer.
    @ViewBuilder
    private var cardBackground: some View {
        switch result.game {
        case .backword:
            Color.backwordBackground
        case .dailyCrossword:
            Color.shareCardDailyBackground
        case .weeklyCrossword:
            Color.shareCardWeeklyBackground
        }
    }

    @ViewBuilder
    private var cardBorder: some View {
        if result.game == .weeklyCrossword {
            RoundedRectangle(cornerRadius: PuzzleResultShareCardLayout.cornerRadius)
                .stroke(proGradient, lineWidth: 1.5)
        }
    }

    private var proGradient: LinearGradient {
        AppGradient.pro
    }

    private func statTile(label: String, value: String, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: scaled(42))
                .fill(Color.black.opacity(0.2))

            Text(label)
                .font(AppFont.shareCardTitle(scaled(31)))
                .foregroundColor(statLabelColor)
                .tracking(scaled(3))
                .frame(width: scaled(392), alignment: .leading)
                .offset(x: scaled(30), y: scaled(28))
            Text(value)
                .font(AppFont.caption(scaled(62)))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(width: scaled(392), alignment: .leading)
                .offset(x: scaled(30), y: scaled(78))
        }
        .frame(width: PuzzleResultShareCardLayout.statWidth, height: height)
    }

    private var ratingStatTile: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: scaled(42))
                .fill(Color.black.opacity(0.2))

            Text("CURRENT RATING")
                .font(AppFont.shareCardTitle(scaled(31)))
                .foregroundColor(statLabelColor)
                .tracking(scaled(3))
                .frame(width: scaled(392), alignment: .leading)
                .offset(x: scaled(30), y: scaled(28))
            Text(result.ratingTier)
                .font(AppFont.caption(scaled(62)))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(width: scaled(392), alignment: .leading)
                .offset(x: scaled(30), y: scaled(78))
            Text("\(result.ratingPoints)/\(result.ratingMaxPoints) pts")
                .font(AppFont.caption(scaled(56)))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(width: scaled(392), alignment: .leading)
                .offset(x: scaled(30), y: scaled(150))
        }
        .frame(width: PuzzleResultShareCardLayout.statWidth, height: scaled(250))
    }

    private var timeStat: PuzzleShareResult.Stat {
        result.timeStat ?? PuzzleShareResult.Stat(label: "TOTAL SOLVED", value: "\(result.totalGamesSolved)")
    }

    private var titleFontSize: CGFloat {
        scaled(max(58, min(86, 86 * 13 / CGFloat(result.issueLabel.count))))
    }

    private var streakValue: String {
        "\(result.streak) \(result.streak == 1 ? "day" : "days")"
    }

    private func shareCardValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: " AM", with: " am")
            .replacingOccurrences(of: " PM", with: " pm")
    }

    private var statLabelColor: Color {
        if result.game.usesHighContrastShareCardStatLabels {
            return .shareCardBackwordStatLabel
        }
        return result.game == .dailyCrossword
            ? .shareCardDailyStatLabel
            : .shareCardWeeklyStatLabel
    }

    private func scaled(_ designValue: CGFloat) -> CGFloat {
        PuzzleResultShareCardLayout.scaled(designValue)
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
        renderer.scale = PuzzleResultShareCardLayout.renderScale
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

/// Shows the 540-point card at its phone-friendly size in Xcode without
/// changing the 1080px dimensions used by `ImageRenderer` for the shared image.
private struct PuzzleResultShareCardPreview: View {
    let result: PuzzleShareResult

    var body: some View {
        PuzzleResultShareCard(result: result)
            .scaleEffect(330.0 / PuzzleResultShareCardLayout.canvasSize)
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
