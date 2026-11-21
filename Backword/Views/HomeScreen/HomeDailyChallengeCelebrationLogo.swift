import SwiftUI

/// Aligns the visible artwork rather than the PNGs' differing transparent margins.
struct HomeDailyChallengeCelebrationLogo: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric private var height: CGFloat
    let game: DailyChallengeGame
    private let compact: Bool

    init(game: DailyChallengeGame, compact: Bool = false) {
        self.game = game
        self.compact = compact
        let logoHeight = compact ? AppLayout.profileDailyLogoHeight : AppLayout.homeDailyCelebrationLogoHeight
        _height = ScaledMetric(wrappedValue: logoHeight)
    }

    @ViewBuilder
    var body: some View {
        switch game {
        case .backword:
            artwork(
                Image(colorScheme == .light ? "BackWordLogo - Light" : "BackWordLogo"),
                canvas: AppLayout.homeDailyCelebrationBackwordCanvasSize,
                bounds: colorScheme == .light
                    ? AppLayout.homeDailyCelebrationBackwordLightArtworkBounds
                    : AppLayout.homeDailyCelebrationBackwordDarkArtworkBounds
            )
        case .crossword:
            Text("QUICK CROSSWORD")
                .font(AppFont.clueLabel())
                .tracking(2)
                .foregroundStyle(game.homeProgressColor)
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .fixedSize(horizontal: false, vertical: true)
        case .anagram:
            let titleSize = compact ? AppLayout.profileDailyGameTitleSize : AppLayout.homeDailyCelebrationGameTitleSize
            Text("ANAGRAM")
                .font(AppFont.clueLabel(titleSize))
                .tracking(2)
                .foregroundStyle(game.homeProgressColor)
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .fixedSize(horizontal: false, vertical: true)
        case .midword:
            artwork(
                Image("MidwordLogo").renderingMode(colorScheme == .dark ? .template : .original),
                canvas: AppLayout.homeDailyCelebrationMidwordCanvasSize,
                bounds: AppLayout.homeDailyCelebrationMidwordArtworkBounds
            )
            .foregroundStyle(AppGradient.midwordLogo)
        }
    }

    private func artwork(_ image: Image, canvas: CGSize, bounds: CGRect) -> some View {
        let scale = height / bounds.height
        // Normalize layout without clipping: the asset's 2x/3x variants have
        // different transparent margins. Let their full ink draw into row padding.
        return image.resizable()
            .frame(width: canvas.width * scale, height: canvas.height * scale)
            .offset(x: -bounds.minX * scale, y: -bounds.minY * scale)
            .frame(width: bounds.width * scale, height: height, alignment: .topLeading)
    }
}
