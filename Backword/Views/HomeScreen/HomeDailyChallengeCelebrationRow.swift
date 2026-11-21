import SwiftUI

struct HomeDailyChallengeCelebrationRow: View {
    static let guideMarkerFillMilliseconds = 550

    enum GuidePhase: CaseIterable {
        case hidden, marker, filled, points
    }

    private enum Accessory {
        case points(Int, isRevealed: Bool)
        case guide(GuidePhase, delay: Double)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var minimumHeight = AppLayout.homeDailyCelebrationRowHeight
    private let game: DailyChallengeGame
    private let showsGame: Bool
    private let accessory: Accessory

    init(progress: DailyChallengeGameProgress, showsGame: Bool, showsPoints: Bool) {
        self.game = progress.game
        self.showsGame = showsGame
        self.accessory = .points(progress.earnedPoints, isRevealed: showsPoints)
    }

    init(game: DailyChallengeGame, guidePhase: GuidePhase, delay: Double = 0) {
        self.game = game
        self.showsGame = guidePhase != .hidden
        self.accessory = .guide(guidePhase, delay: delay)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppLayout.homeDailyCelebrationRowSpacing) {
                    logo
                    HStack {
                        Spacer()
                        trailingContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: AppLayout.homeDailyCelebrationPadding) {
                    logo
                        .frame(maxWidth: .infinity, alignment: .leading)
                    trailingContent
                }
            }
        }
        .frame(minHeight: minimumHeight)
        .padding(.horizontal, AppLayout.homeDailyCelebrationPadding)
        .padding(.vertical, AppLayout.homeDailyCelebrationRowSpacing)
        .background(game.homeProgressColor.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .opacity(showsGame ? 1 : 0)
        .offset(y: showsGame || reduceMotion ? 0 : AppLayout.homeDailyCelebrationRevealOffset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHidden(!showsGame || !isAccessoryRevealed)
    }

    private var logo: some View {
        HomeDailyChallengeCelebrationLogo(game: game)
    }

    var accessibilityDescription: String {
        if case let .points(earned, _) = accessory {
            return "\(game.displayName), \(earned) of \(DailyChallengeSnapshot.maximumPointsPerGame) points"
        }
        return "\(game.displayName), up to \(DailyChallengeSnapshot.maximumPointsPerGame) points"
    }

    private var isAccessoryRevealed: Bool {
        if case let .points(_, isRevealed) = accessory { return isRevealed }
        return true
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch accessory {
        case let .points(earned, isRevealed):
            points(earned, isRevealed: isRevealed)
        case let .guide(phase, delay):
            guidePoints(phase: phase, delay: delay)
        }
    }

    private func guidePoints(phase: GuidePhase, delay: Double) -> some View {
        let showsPoints = phase == .points
        let fillsMarker = phase == .filled || showsPoints
        let markerWidth = AppLayout.dailyIntervlsGuideMarkerWidth
        let fillAnimation = reduceMotion ? nil : Animation.easeInOut(
            duration: Double(Self.guideMarkerFillMilliseconds) / 1_000
        ).delay(delay)
        let transition = reduceMotion ? nil : Animation.easeInOut(duration: 0.28).delay(delay)

        return points(DailyChallengeSnapshot.maximumPointsPerGame, isRevealed: showsPoints)
            .animation(transition, value: showsPoints)
            .overlay(alignment: .trailing) {
                HomeDailyChallengeMarker(progress: .init(game: game, state: .notStarted), width: markerWidth)
                    .overlay {
                        HomeDailyChallengeMarker(progress: .init(game: game, state: .finished(won: true)),
                                                 width: markerWidth)
                            .mask(alignment: .leading) {
                                Rectangle().scaleEffect(x: fillsMarker ? 1 : 0, y: 1, anchor: .leading)
                            }
                            .animation(fillAnimation, value: fillsMarker)
                    }
                    .opacity(showsPoints ? 0 : 1)
                    .scaleEffect(showsPoints && !reduceMotion ? 0.6 : 1)
                    .animation(transition, value: showsPoints)
                    .accessibilityHidden(true)
            }
    }

    private func points(_ earned: Int, isRevealed: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppLayout.homeDailyMarkerSpacing) {
            Text("\(earned)")
                .font(AppFont.statNumber(AppLayout.homeDailyCelebrationScoreSize))
                .foregroundStyle(game.homeProgressColor)
            Text("/ \(DailyChallengeSnapshot.maximumPointsPerGame)")
                .font(AppFont.caption())
                .foregroundStyle(Color.appTextSecondary)
        }
        .monospacedDigit()
        .fixedSize()
        .opacity(isRevealed ? 1 : 0)
        .scaleEffect(isRevealed || reduceMotion ? 1 : 0.6)
    }
}
