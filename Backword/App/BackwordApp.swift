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
    @StateObject private var appReviewPromptService: AppReviewPromptService
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
                .environmentObject(appReviewPromptService)
                .task {
                    await adService.prepareAdsIfNeeded()
                }
        }
    }

    init() {
        let statsService = StatsService()
        let puzzleService = PuzzleService()
        let storeService = StoreService()
        let adService = AdService()
        let ratingService = OverallRatingService()
        let appReviewPromptService = AppReviewPromptService()

        _statsService = StateObject(wrappedValue: statsService)
        _puzzleService = StateObject(wrappedValue: puzzleService)
        _storeService = StateObject(wrappedValue: storeService)
        _adService = StateObject(wrappedValue: adService)
        _ratingService = StateObject(wrappedValue: ratingService)
        _appReviewPromptService = StateObject(wrappedValue: appReviewPromptService)
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
