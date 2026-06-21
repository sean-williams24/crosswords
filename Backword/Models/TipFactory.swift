//  TipFactory.swift

import TipKit

enum SettingsTipPresentationReadiness {
    static func canPresent(
        launchSplashDidComplete: Bool,
        navigationBarDidAppear: Bool,
        adStartupDidComplete: Bool,
        isPresentingFullScreenAd: Bool,
        isHomeNavigationActive: Bool,
        didReturnFromDailyGame: Bool
    ) -> Bool {
        launchSplashDidComplete
            && navigationBarDidAppear
            && adStartupDidComplete
            && !isPresentingFullScreenAd
            && !isHomeNavigationActive
            && didReturnFromDailyGame
    }
}

struct SettingsTip: Tip {
    var title: Text {
        Text("Settings")
            .font(AppFont.caption(20))
    }

    var message: Text? {
        Text("Customize your game settings, including colour scheme and difficulty.")
            .font(AppFont.caption(13))
    }

    @Parameter
    static var homeChromeReady: Bool = false

    var rules: [Rule] {
        [
            #Rule(Self.$homeChromeReady) { $0 == true }
        ]
    }

    var options: [TipOption] {
        Tips.MaxDisplayCount(1)
    }
}

struct BackwordInstructionsTip: Tip {
    var title: Text {
        Text("How to play")
            .font(AppFont.caption(20))
    }

    var message: Text? {
        Text("Tap the info icon at any time to view game information")
            .font(AppFont.caption(13))
    }

    @Parameter
    static var actionCompleted: Bool = false

    var rules: [Rule] {
        [
            #Rule(Self.$actionCompleted) { $0 == true }
        ]
    }

    var options: [TipOption] {
        Tips.MaxDisplayCount(1)
    }
}
