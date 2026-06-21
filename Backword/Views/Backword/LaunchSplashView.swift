import SwiftUI

struct LaunchSplashAnimationTiming: Equatable {
    let holdNanoseconds: UInt64
    let fadeDuration: Double
    let fadeNanoseconds: UInt64

    static let standard = LaunchSplashAnimationTiming(
        holdNanoseconds: 850_000_000,
        fadeDuration: 0.32,
        fadeNanoseconds: 320_000_000
    )

    static let reduceMotion = LaunchSplashAnimationTiming(
        holdNanoseconds: 350_000_000,
        fadeDuration: 0.2,
        fadeNanoseconds: 200_000_000
    )

    static func timing(reduceMotion: Bool) -> LaunchSplashAnimationTiming {
        reduceMotion ? .reduceMotion : .standard
    }
}

struct LaunchSplashLogoSizing {
    static let phoneFrame: CGFloat = 96

    static func frame(userInterfaceIdiom: UIUserInterfaceIdiom) -> CGFloat {
        userInterfaceIdiom == .pad ? phoneFrame * 2 : phoneFrame
    }
}

struct LaunchSplashView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSplash = true
    @State private var contentOpacity = 0.0
    @State private var logoOpacity = 0.0
    @State private var logoScale = 0.86
    @State private var logoOffset: CGFloat = 12

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .opacity(contentOpacity)
                .allowsHitTesting(!isShowingSplash)

            if isShowingSplash {
                splash
                    .transition(.opacity)
            }
        }
        .task {
            await playLaunchAnimation()
        }
    }

    private var splash: some View {
        ZStack {
            AppBackgroundGradient()

            BackwordLogo(frame: LaunchSplashLogoSizing.frame(userInterfaceIdiom: UIDevice.current.userInterfaceIdiom))
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
                .offset(y: logoOffset)
        }
        .ignoresSafeArea()
    }

    @MainActor
    private func playLaunchAnimation() async {
        let timing = LaunchSplashAnimationTiming.timing(reduceMotion: reduceMotion)

        if reduceMotion {
            contentOpacity = 1
            logoOpacity = 1
            try? await Task.sleep(nanoseconds: timing.holdNanoseconds)
            withAnimation(.easeOut(duration: timing.fadeDuration)) {
                isShowingSplash = false
            }
            return
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.74)) {
            logoOpacity = 1
            logoScale = 1
            logoOffset = 0
        }

        try? await Task.sleep(nanoseconds: timing.holdNanoseconds)

        withAnimation(.easeInOut(duration: timing.fadeDuration)) {
            logoOpacity = 0
            logoScale = 1.06
            contentOpacity = 1
        }

        try? await Task.sleep(nanoseconds: timing.fadeNanoseconds)
        isShowingSplash = false
    }
}

#Preview {
    let puzzleService = PuzzleService()
    let storeService = StoreService()
    LaunchSplashView {
        HomeView(viewModel: HomeViewModel(puzzleService: puzzleService, storeService: storeService))
            .environmentObject(StatsService())
            .environmentObject(puzzleService)
            .environmentObject(storeService)
            .environmentObject(AdService())
            .environmentObject(OverallRatingService())
    }
}
