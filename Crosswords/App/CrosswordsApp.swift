import SwiftUI

@main
struct CrosswordsApp: App {
    @StateObject private var statsService = StatsService()
    @StateObject private var puzzleService = PuzzleService()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(statsService)
                .environmentObject(puzzleService)
        }
    }
}
