import Testing
@testable import Backword

@Suite("Launch Splash View Tests")
struct LaunchSplashViewTests {

    @Test("Standard launch splash timing holds long enough to show the logo animation")
    func standardTimingShowsLogoAnimation() {
        let timing = LaunchSplashAnimationTiming.timing(reduceMotion: false)

        #expect(timing.holdNanoseconds == 850_000_000)
        #expect(timing.fadeDuration == 0.32)
        #expect(timing.fadeNanoseconds == 320_000_000)
    }

    @Test("Reduce Motion launch splash timing shortens animation")
    func reduceMotionTimingShortensAnimation() {
        let standard = LaunchSplashAnimationTiming.timing(reduceMotion: false)
        let reduceMotion = LaunchSplashAnimationTiming.timing(reduceMotion: true)

        #expect(reduceMotion.holdNanoseconds < standard.holdNanoseconds)
        #expect(reduceMotion.fadeDuration < standard.fadeDuration)
        #expect(reduceMotion.fadeNanoseconds < standard.fadeNanoseconds)
    }

    @Test("iPad launch splash logo is twice the phone size")
    func iPadLogoIsTwicePhoneSize() {
        let phoneFrame = LaunchSplashLogoSizing.frame(userInterfaceIdiom: .phone)
        let iPadFrame = LaunchSplashLogoSizing.frame(userInterfaceIdiom: .pad)

        #expect(phoneFrame == 96)
        #expect(iPadFrame == phoneFrame * 2)
    }

    @Test("Settings tip waits for splash completion and home navigation bar")
    func settingsTipWaitsForSplashAndNavigationBar() {
        #expect(SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: false,
            navigationBarDidAppear: false,
            adStartupDidComplete: false,
            isPresentingFullScreenAd: false,
            isHomeNavigationActive: false,
            didReturnFromDailyGame: false
        ) == false)
        #expect(SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: false,
            navigationBarDidAppear: true,
            adStartupDidComplete: true,
            isPresentingFullScreenAd: false,
            isHomeNavigationActive: false,
            didReturnFromDailyGame: true
        ) == false)
        #expect(SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: true,
            navigationBarDidAppear: false,
            adStartupDidComplete: true,
            isPresentingFullScreenAd: false,
            isHomeNavigationActive: false,
            didReturnFromDailyGame: true
        ) == false)
        #expect(SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: true,
            navigationBarDidAppear: true,
            adStartupDidComplete: false,
            isPresentingFullScreenAd: false,
            isHomeNavigationActive: false,
            didReturnFromDailyGame: true
        ) == false)
        #expect(SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: true,
            navigationBarDidAppear: true,
            adStartupDidComplete: true,
            isPresentingFullScreenAd: true,
            isHomeNavigationActive: false,
            didReturnFromDailyGame: true
        ) == false)
        #expect(SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: true,
            navigationBarDidAppear: true,
            adStartupDidComplete: true,
            isPresentingFullScreenAd: false,
            isHomeNavigationActive: true,
            didReturnFromDailyGame: true
        ) == false)
        #expect(SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: true,
            navigationBarDidAppear: true,
            adStartupDidComplete: true,
            isPresentingFullScreenAd: false,
            isHomeNavigationActive: false,
            didReturnFromDailyGame: false
        ) == false)
        #expect(SettingsTipPresentationReadiness.canPresent(
            launchSplashDidComplete: true,
            navigationBarDidAppear: true,
            adStartupDidComplete: true,
            isPresentingFullScreenAd: false,
            isHomeNavigationActive: false,
            didReturnFromDailyGame: true
        ))
    }
}
