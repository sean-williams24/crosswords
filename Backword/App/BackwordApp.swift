import SwiftUI
import TipKit

@main
struct BackwordApp: App {
    @StateObject private var statsService = StatsService()
    @StateObject private var puzzleService = PuzzleService()
    @StateObject private var storeService = StoreService()
    @StateObject private var adService = AdService()
    @StateObject private var ratingService = OverallRatingService()
    @AppStorage("appColorScheme") private var appColorScheme: Int = 2

    var body: some Scene {
        WindowGroup {
            HomeView()
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
