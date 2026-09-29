import SwiftUI

enum AnagramHintBannerMode: Equatable {
    case watchAd
    case timePenalty
    case adUnavailable

    init(isProUser: Bool) {
        self = isProUser ? .timePenalty : .watchAd
    }

    var title: String {
        switch self {
        case .watchAd: "Want a free hint?"
        case .timePenalty: "Reveal a letter?"
        case .adUnavailable: "Ad unavailable"
        }
    }

    var subtitle: String {
        switch self {
        case .watchAd: "Watch a short ad to reveal one."
        case .timePenalty: "Reveal one letter with a 30-second penalty."
        case .adUnavailable: "The ad did not grant a hint. You can use the 30-second alternative."
        }
    }

    var primaryButtonTitle: String {
        self == .watchAd ? "Watch" : "Reveal letter · +30 seconds"
    }

    var showsAdFreeButton: Bool { self != .timePenalty }
}

enum AnagramHintAdAction: Equatable {
    case reveal
    case offerTimePenalty
    case close

    init(result: AdService.RewardedAdResult) {
        switch result {
        case .earnedReward: self = .reveal
        case .unavailable, .failedToPresent: self = .offerTimePenalty
        case .dismissedWithoutReward: self = .close
        }
    }
}

struct AnagramHintBanner: View {
    let mode: AnagramHintBannerMode
    let narrowsAnswers: Bool
    let isBusy: Bool
    let onPrimaryAction: () -> Void
    let onGoAdFree: () -> Void
    let onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                verticalContent
            } else {
                horizontalContent
            }
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
        .background(Color.anagramSurface)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(mode.title)
                .font(AppFont.clueLabel(13))
                .foregroundStyle(Color.anagramInk)
            Text(mode.subtitle)
                .font(AppFont.caption(12))
                .foregroundStyle(Color.anagramInk.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            if narrowsAnswers {
                Text("The locked letter may rule out some other answers.")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.anagramInk.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var primaryButton: some View {
        Button(action: onPrimaryAction) {
            Text(mode.primaryButtonTitle)
                .font(AppFont.clueLabel(12))
                .foregroundStyle(Color.anagramOnOrange)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 40)
                .padding(.horizontal, 12)
                .background(Color.anagramOrange.opacity(isBusy ? 0.55 : 1))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private var adFreeButton: some View {
        Button(action: onGoAdFree) {
            Text("Go ad-free")
                .font(AppFont.clueLabel(12))
                .foregroundStyle(Color.anagramOrange)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 40)
                .padding(.horizontal, 12)
                .background(Color.anagramOrange.opacity(0.12))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(AppFont.body())
                .foregroundStyle(Color.anagramInk.opacity(0.72))
                .frame(minWidth: 30, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close hint options")
        .disabled(isBusy)
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            primaryButton
            if mode.showsAdFreeButton { adFreeButton }
        }
    }

    private var hintIcon: some View {
        Image(systemName: mode == .watchAd ? "play.circle.fill" : "lightbulb.fill")
            .font(AppFont.body(24))
            .foregroundStyle(Color.anagramOrange)
    }

    private var horizontalContent: some View {
        HStack(spacing: 10) {
            hintIcon
            heading
            Spacer(minLength: 0)
            actionButtons
            closeButton
        }
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                hintIcon
                heading
                Spacer(minLength: 0)
                closeButton
            }
            actionButtons
        }
    }
}
