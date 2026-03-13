import SwiftUI

@main
struct CrosswordsApp: App {
    @StateObject private var statsService = StatsService()
    @StateObject private var puzzleService = PuzzleService()
    @StateObject private var storeService = StoreService()
    @StateObject private var adService = AdService()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(statsService)
                .environmentObject(puzzleService)
                .environmentObject(storeService)
                .environmentObject(adService)
        }
    }
}
