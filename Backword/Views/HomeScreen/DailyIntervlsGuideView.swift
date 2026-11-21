import SwiftUI

struct DailyIntervlsGuideView: View {
    enum Mode {
        case onboarding(DailyIntervlsGuideStep)
        case manual

        var isOnboarding: Bool {
            if case .onboarding = self { return true }
            return false
        }

        var startingStep: DailyIntervlsGuideStep {
            if case let .onboarding(step) = self { return step }
            return .gameplay
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isHeadingFocused: Bool
    @State private var step: DailyIntervlsGuideStep
    @State private var ratingProgress: Double = 0

    private let mode: Mode
    private let isPro: Bool
    private let hidesRatingTrack: Bool
    private let acknowledgeGameplay: () -> Void
    private let finishOnboarding: () -> Void
    private let dismiss: () -> Void
    private let dismissScoring: (() -> Void)?

    init(
        mode: Mode = .manual,
        isPro: Bool = false,
        hidesRatingTrack: Bool = false,
        acknowledgeGameplay: @escaping () -> Void = {},
        finishOnboarding: @escaping () -> Void = {},
        dismissScoring: (() -> Void)? = nil,
        dismiss: @escaping () -> Void
    ) {
        self.mode = mode
        self.isPro = isPro
        self.hidesRatingTrack = hidesRatingTrack
        self.acknowledgeGameplay = acknowledgeGameplay
        self.finishOnboarding = finishOnboarding
        self.dismiss = dismiss
        self.dismissScoring = dismissScoring
        _step = State(initialValue: mode.startingStep)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appModalBackdrop
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                card
                    .frame(width: max(0, min(AppLayout.homeDailyCelebrationMaxWidth,
                        geometry.size.width - AppLayout.homeDailyCelebrationMargin * 2)))
                    .frame(maxHeight: max(0, geometry.size.height - AppLayout.homeDailyCelebrationMargin * 2))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            if !mode.isOnboarding {
                if step == .scoring { closeScoring() } else { dismiss() }
            }
        }
        .task(id: step) {
            isHeadingFocused = true
            if step == .scoring { await animateRating() }
        }
    }

    private var card: some View {
        VStack(spacing: AppLayout.homeDailyCelebrationSpacing) {
            ViewThatFits(in: .vertical) {
                guideContent.fixedSize(horizontal: false, vertical: true)
                ScrollView {
                    guideContent
                }
                .id(step)
            }
            actions
        }
        .padding(AppLayout.homeDailyCelebrationCardPadding)
        .background { glassBackground }
    }

    private var guideContent: some View {
        VStack(alignment: .leading, spacing: AppLayout.homeDailyCelebrationSpacing) {
            VStack(spacing: AppLayout.homeDailyCelebrationRowSpacing) {
                Text(step.title)
                    .font(AppFont.header(AppLayout.homeDailyCelebrationTitleSize))
                    .foregroundStyle(Color.appTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isHeadingFocused)
                if step == .gameplay {
                    explanation(DailyIntervlsGuideStep.gameplayIntroduction)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            if step == .gameplay {
                DailyIntervlsLineupView()
            } else {
                DailyIntervlsRatingDemoView(progress: ratingProgress, isPro: isPro, hidesTrack: hidesRatingTrack)
                ratingBulletList
            }
        }
    }

    private var ratingBulletList: some View {
        VStack(alignment: .leading, spacing: AppLayout.homeDailyCelebrationRowSpacing) {
            ForEach(DailyIntervlsGuideStep.ratingBulletPoints, id: \.self) { point in
                HStack(alignment: .firstTextBaseline, spacing: AppLayout.homeDailyCelebrationRowSpacing) {
                    explanation("•")
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityHidden(true)
                    explanation(point)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func explanation(_ text: String) -> some View {
        Text(text)
            .font(AppFont.caption())
            .foregroundStyle(Color.appTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func animateRating() async {
        guard !reduceMotion else {
            ratingProgress = 1
            return
        }
        do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
        withAnimation(.linear(duration: 4.5)) {
            ratingProgress = 1
        }
    }

    private var actions: some View {
        VStack(spacing: AppLayout.homeDailyCelebrationRowSpacing) {
            Button(action: advanceOrFinish) {
                Text(step.actionTitle(isOnboarding: mode.isOnboarding))
                    .font(AppFont.clueLabel())
                    .multilineTextAlignment(.center)
                    .padding(AppLayout.homeDailyCelebrationPadding)
                    .frame(maxWidth: .infinity, minHeight: AppLayout.minimumTouchTarget)
                    .background(Color.appAccent.opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.appAccent.opacity(0.4),
                                                    lineWidth: AppLayout.homeDailyCardBorderWidth))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)

            if !mode.isOnboarding && step == .gameplay {
                Button(action: dismiss) {
                    Text("Close")
                        .font(AppFont.clueLabel())
                        .frame(minWidth: AppLayout.minimumTouchTarget, minHeight: AppLayout.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
        }
        .foregroundStyle(Color.appTextPrimary)
        .id(step)
    }

    @ViewBuilder
    private var glassBackground: some View {
        let shape = RoundedRectangle(cornerRadius: AppLayout.homeDailyCelebrationCornerRadius)
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            shape.fill(.regularMaterial)
        }
    }

    private func advanceOrFinish() {
        switch step {
        case .gameplay:
            withTransaction(Self.pageAdvanceTransaction) {
                if mode.isOnboarding { acknowledgeGameplay() }
                step = .scoring
            }
        case .scoring:
            if mode.isOnboarding { finishOnboarding() }
            closeScoring()
        }
    }

    static var pageAdvanceTransaction: Transaction {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return transaction
    }

    private func closeScoring() {
        (dismissScoring ?? dismiss)()
    }
}

#if DEBUG
#Preview("Daily Intervls · Gameplay · Dark") {
    DailyIntervlsGuideView(mode: .onboarding(.gameplay), dismiss: {})
        .background(AppBackgroundGradient())
        .preferredColorScheme(.dark)
}

#Preview("Daily Intervls · Scoring · Animated") {
    DailyIntervlsGuideView(mode: .onboarding(.scoring), dismiss: {})
        .background(AppBackgroundGradient())
        .preferredColorScheme(.light)
}

#Preview("Daily Intervls · Scoring · Pro · Reduce Motion") {
    DailyIntervlsGuideView(mode: .onboarding(.scoring), isPro: true, dismiss: {})
        .background(AppBackgroundGradient())
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\._accessibilityReduceMotion, true)
}

#Preview("Daily Intervls · Manual · Accessibility") {
    DailyIntervlsGuideView(dismiss: {})
        .background(AppBackgroundGradient())
        .environment(\.dynamicTypeSize, .accessibility3)
        .environment(\._accessibilityReduceMotion, true)
}
#endif
