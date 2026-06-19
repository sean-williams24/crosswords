import SwiftUI
import TipKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackwordAnalyticsService.shared.configureIfPossible()
        return true
    }
}

@main
struct BackwordApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var statsService = StatsService()
    @StateObject private var puzzleService = PuzzleService()
    @StateObject private var storeService = StoreService()
    @StateObject private var adService = AdService()
    @StateObject private var ratingService = OverallRatingService()
    @AppStorage("appColorScheme") private var appColorScheme: Int = 2

    var body: some Scene {
        WindowGroup {
            LaunchSplashView {
                HomeView()
            }
                .preferredColorScheme(selectedScheme)
                .environmentObject(statsService)
                .environmentObject(puzzleService)
                .environmentObject(storeService)
                .environmentObject(adService)
                .environmentObject(ratingService)
        }
    }

    init() {
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    private var selectedScheme: ColorScheme? {
            switch appColorScheme {
            case 1: return .light
            case 2: return .dark
            default: return nil
            }
        }
}
