import Foundation
import StoreKit
import UIKit

struct AppReviewPromptState: Codable, Equatable {
    var eligibleCompletionCount: Int
    var lastRequestDate: Date?
    var completionCountAtLastRequest: Int
    var countedPuzzleIds: Set<String>

    init(
        eligibleCompletionCount: Int = 0,
        lastRequestDate: Date? = nil,
        completionCountAtLastRequest: Int = 0,
        countedPuzzleIds: Set<String> = []
    ) {
        self.eligibleCompletionCount = eligibleCompletionCount
        self.lastRequestDate = lastRequestDate
        self.completionCountAtLastRequest = completionCountAtLastRequest
        self.countedPuzzleIds = countedPuzzleIds
    }
}

@MainActor
final class AppReviewPromptService: ObservableObject {
    private enum Constants {
        static let firstPromptCompletionCount = 3
        static let repeatPromptAdditionalCompletions = 5
        static let repeatPromptCooldownDays = 90
    }

    private let userDefaults: UserDefaults
    private let stateKey: String
    private let now: () -> Date
    private let requestReview: () -> Void
    private let calendar: Calendar

    init(
        userDefaults: UserDefaults = .standard,
        stateKey: String = "appReviewPromptState",
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        requestReview: @escaping () -> Void = AppReviewPromptService.requestReviewInActiveScene
    ) {
        self.userDefaults = userDefaults
        self.stateKey = stateKey
        self.calendar = calendar
        self.now = now
        self.requestReview = requestReview
    }

    func recordEligibleCrosswordCompletion(puzzleId: String, gaveUp: Bool) {
        guard !gaveUp else { return }

        var state = loadState()
        guard !state.countedPuzzleIds.contains(puzzleId) else { return }

        state.countedPuzzleIds.insert(puzzleId)
        state.eligibleCompletionCount += 1

        let currentDate = now()
        if Self.shouldRequestReview(state: state, now: currentDate, calendar: calendar) {
            state.lastRequestDate = currentDate
            state.completionCountAtLastRequest = state.eligibleCompletionCount
            saveState(state)
            requestReview()
        } else {
            saveState(state)
        }
    }

    func loadState() -> AppReviewPromptState {
        guard let data = userDefaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(AppReviewPromptState.self, from: data) else {
            return AppReviewPromptState()
        }
        return state
    }

    static func shouldRequestReview(
        state: AppReviewPromptState,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let lastRequestDate = state.lastRequestDate else {
            return state.eligibleCompletionCount >= Constants.firstPromptCompletionCount
        }

        guard let cooldownEnd = calendar.date(
            byAdding: .day,
            value: Constants.repeatPromptCooldownDays,
            to: lastRequestDate
        ), now >= cooldownEnd else {
            return false
        }

        let completionsSinceLastRequest = state.eligibleCompletionCount - state.completionCountAtLastRequest
        return completionsSinceLastRequest >= Constants.repeatPromptAdditionalCompletions
    }

    private func saveState(_ state: AppReviewPromptState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults.set(data, forKey: stateKey)
    }

    private static func requestReviewInActiveScene() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }
        SKStoreReviewController.requestReview(in: scene)
        print("[AppReviewPromptService] Requesting App Store review")
    }
}
