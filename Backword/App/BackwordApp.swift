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
    @StateObject private var statsService: StatsService
    @StateObject private var puzzleService: PuzzleService
    @StateObject private var storeService: StoreService
    @StateObject private var adService: AdService
    @StateObject private var ratingService: OverallRatingService
    @StateObject private var homeViewModel: HomeViewModel
    @AppStorage("appColorScheme") private var appColorScheme: Int = 2

    var body: some Scene {
        WindowGroup {
            LaunchSplashView {
                HomeView(viewModel: homeViewModel)
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
        let statsService = StatsService()
        let puzzleService = PuzzleService()
        let storeService = StoreService()
        let adService = AdService()
        let ratingService = OverallRatingService()

        _statsService = StateObject(wrappedValue: statsService)
        _puzzleService = StateObject(wrappedValue: puzzleService)
        _storeService = StateObject(wrappedValue: storeService)
        _adService = StateObject(wrappedValue: adService)
        _ratingService = StateObject(wrappedValue: ratingService)
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(
            puzzleService: puzzleService,
            storeService: storeService
        ))
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
