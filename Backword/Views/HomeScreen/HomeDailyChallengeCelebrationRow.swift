import SwiftUI

struct HomeDailyChallengeCelebrationRow: View {
    static let markerFillMilliseconds = 550

    enum RevealPhase: CaseIterable {
        case hidden, marker, filled, points
    }

    private enum Accessory {
        case points(Int, isRevealed: Bool)
        case lineup(progress: DailyChallengeGameProgress?, phase: RevealPhase, delay: Double)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var minimumHeight = AppLayout.homeDailyCelebrationRowHeight
    @ScaledMetric private var compactMinimumHeight = AppLayout.profileDailyRowHeight
    @ScaledMetric private var profileMarkerWidth = AppLayout.profileDailyMarkerWidth
    @ScaledMetric private var markerHeight = AppLayout.homeDailyMarkerHeight
    private let game: DailyChallengeGame
    private let showsGame: Bool
    private let accessory: Accessory

    init(progress: DailyChallengeGameProgress, showsGame: Bool, showsPoints: Bool) {
        self.game = progress.game
        self.showsGame = showsGame
        self.accessory = .points(progress.earnedPoints, isRevealed: showsPoints)
    }

    init(game: DailyChallengeGame, guidePhase: RevealPhase, delay: Double = 0) {
        self.game = game
        self.showsGame = guidePhase != .hidden
        self.accessory = .lineup(progress: nil, phase: guidePhase, delay: delay)
    }

    init(progress: DailyChallengeGameProgress, profilePhase: RevealPhase, delay: Double = 0) {
        self.game = progress.game
        self.showsGame = profilePhase != .hidden
        self.accessory = .lineup(progress: progress, phase: profilePhase, delay: delay)
    }

    private var isCompact: Bool {
        if case let .lineup(progress, _, _) = accessory { return progress != nil }
        return false
    }

    var body: some View {
        let horizontalPadding = isCompact ? AppLayout.profileDailyRowHorizontalPadding : AppLayout.homeDailyCelebrationPadding
        let verticalPadding = isCompact ? AppLayout.profileDailyRowVerticalPadding : AppLayout.homeDailyCelebrationRowSpacing
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppLayout.homeDailyCelebrationRowSpacing) {
                    logo
                        .padding(.top, isCompact ? AppLayout.profileDailyAccessibilityLogoTopPadding : 0)
                    HStack {
                        Spacer()
                        trailingContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: horizontalPadding) {
                    logo
                        .frame(maxWidth: .infinity, alignment: .leading)
                    trailingContent
                }
            }
        }
        .frame(minHeight: isCompact ? compactMinimumHeight : minimumHeight)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(game.homeProgressColor.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .opacity(showsGame ? 1 : 0)
        .offset(y: showsGame || reduceMotion ? 0 : AppLayout.homeDailyCelebrationRevealOffset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHidden(!showsGame || !isAccessoryRevealed)
    }

    private var logo: some View {
        HomeDailyChallengeCelebrationLogo(game: game, compact: isCompact)
    }

    var accessibilityDescription: String {
        let maximum = DailyChallengeSnapshot.maximumPointsPerGame
        switch accessory {
        case let .points(earned, _):
            return "\(game.displayName), \(earned) of \(maximum) points"
        case let .lineup(progress?, _, _):
            return "\(progress.accessibilityLabel), \(progress.earnedPoints) of \(maximum) points"
        case .lineup:
            return "\(game.displayName), up to \(maximum) points"
        }
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
        case let .lineup(progress, phase, delay):
            lineupPoints(progress: progress, phase: phase, delay: delay)
        }
    }

    @ViewBuilder
    private func lineupPoints(progress: DailyChallengeGameProgress?, phase: RevealPhase, delay: Double) -> some View {
        let showsPoints = phase == .points
        let fillsMarker = phase == .filled || showsPoints
        let transition = reduceMotion ? nil : Animation.easeInOut(duration: 0.28).delay(delay)
        let target = progress ?? DailyChallengeGameProgress(game: game, state: .finished(won: true))
        let score = points(progress?.earnedPoints ?? DailyChallengeSnapshot.maximumPointsPerGame, isRevealed: showsPoints)
            .animation(transition, value: showsPoints)
        let marker = lineupMarker(progress: target, fillsMarker: fillsMarker, delay: delay)

        if isCompact {
            score
                .frame(minWidth: profileMarkerWidth, alignment: .trailing)
                .padding(.bottom, markerHeight + AppLayout.homeDailyMarkerSpacing)
                .overlay {
                    GeometryReader { geometry in
                        marker
                            .offset(y: showsPoints ? 0 : (markerHeight - geometry.size.height) / 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                    .animation(transition, value: showsPoints)
                }
        } else {
            score.overlay(alignment: .trailing) {
                marker
                    .opacity(showsPoints ? 0 : 1)
                    .scaleEffect(showsPoints && !reduceMotion ? 0.6 : 1)
                    .animation(transition, value: showsPoints)
            }
        }
    }

    private func lineupMarker(progress: DailyChallengeGameProgress, fillsMarker: Bool, delay: Double) -> some View {
        let width = isCompact ? AppLayout.profileDailyMarkerWidth : AppLayout.dailyIntervlsGuideMarkerWidth
        let fillAnimation = reduceMotion ? nil : Animation.easeInOut(
            duration: Double(Self.markerFillMilliseconds) / 1_000
        ).delay(delay)

        return HomeDailyChallengeMarker(progress: .init(game: game, state: .notStarted), width: width)
            .overlay {
                if progress.state != .notStarted {
                    HomeDailyChallengeMarker(progress: progress, width: width)
                        .mask(alignment: .leading) {
                            Rectangle().scaleEffect(x: fillsMarker ? 1 : 0, y: 1, anchor: .leading)
                        }
                        .animation(fillAnimation, value: fillsMarker)
                }
            }
            .accessibilityHidden(true)
    }

    private func points(_ earned: Int, isRevealed: Bool) -> some View {
        let scoreSize = isCompact ? AppLayout.profileDailyScoreSize : AppLayout.homeDailyCelebrationScoreSize
        return HStack(alignment: .firstTextBaseline, spacing: AppLayout.homeDailyMarkerSpacing) {
            Text("\(earned)")
                .font(AppFont.statNumber(scoreSize))
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
