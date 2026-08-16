import Foundation
import Supabase
import Testing
@testable import Backword

@Suite("Account Sync Tests")
struct AccountSyncTests {
    @Test("Signed-in progress paths are isolated from the guest path")
    func progressNamespacesAreIsolated() {
        let base = URL(fileURLWithPath: "/tmp/backword-progress")
        defer { ProgressStorageNamespace.activate(accountID: nil) }

        ProgressStorageNamespace.activate(accountID: nil)
        #expect(ProgressStorageNamespace.directory(base: base) == base)

        ProgressStorageNamespace.activate(accountID: "account-a")
        #expect(ProgressStorageNamespace.directory(base: base).path == "/tmp/backword-progress/users/account-a")

        ProgressStorageNamespace.activate(accountID: "account-b")
        #expect(ProgressStorageNamespace.directory(base: base).path == "/tmp/backword-progress/users/account-b")
    }

    @Test("A solved Backword record wins over in-progress local guesses")
    func solvedBackwordWinsMerge() {
        var local = BackwordProgress(date: "2026-08-06")
        local.guesses = ["PLANET", "GARDEN"]

        var remote = BackwordProgress(date: "2026-08-06")
        remote.guesses = ["PLANET"]
        remote.wonFlag = true
        remote.completedAt = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(CloudProgressRanking.shouldReplace(
            local: local,
            with: remote,
            formatter: ISO8601DateFormatter()
        ))
    }

    @Test("Further crossword progress wins when neither record is terminal")
    func furthestCrosswordProgressWinsMerge() {
        var local = UserProgress(puzzleId: "daily-1", size: 9, puzzleDate: "2026-08-06", totalClues: 12)
        local.completedClueIds = [1]

        var remote = UserProgress(puzzleId: "daily-1", size: 9, puzzleDate: "2026-08-06", totalClues: 12)
        remote.completedClueIds = [1, 2]

        #expect(CloudProgressRanking.shouldReplace(
            local: local,
            with: remote,
            formatter: ISO8601DateFormatter()
        ))
    }

    @Test("An entitlement function's safe response body is shown to the account holder")
    func entitlementFunctionFailureUsesResponseBody() {
        let error = FunctionsError.httpError(
            code: 400,
            data: Data("Apple Server API credentials are invalid".utf8)
        )

        #expect(AccountFunctionError.message(for: error) == "Apple Server API credentials are invalid")
    }

    @Test("An empty entitlement function response retains its HTTP status")
    func entitlementFunctionFailureWithoutBodyUsesStatus() {
        let error = FunctionsError.httpError(code: 400, data: Data())

        #expect(AccountFunctionError.message(for: error) == "Subscription linking failed (server returned 400).")
    }

    @Test("Account function requests use the signed-in session token")
    func accountFunctionRequestUsesAccessToken() {
        #expect(AccountFunctionRequest.authenticatedHeaders(accessToken: "session-token") == [
            "Authorization": "Bearer session-token"
        ])
    }

    @Test("Task cancellation is not shown as an account error")
    func cancellationIsNotPresentedAsAccountError() {
        #expect(!AccountErrorPresentation.shouldPresent(CancellationError()))
        #expect(!AccountErrorPresentation.shouldPresent(
            NSError(domain: "example", code: 1),
            taskIsCancelled: true
        ))
    }

    @Test("Genuine account errors remain visible")
    func genuineAccountErrorIsPresented() {
        #expect(AccountErrorPresentation.shouldPresent(
            NSError(domain: "example", code: 1),
            taskIsCancelled: false
        ))
    }

    @Test("A confirmed cross-account purchase conflict has clear device-only Pro copy")
    func linkedElsewherePurchasePresentation() {
        #expect(AccountEntitlementPresentation.isAlreadyLinkedPurchaseError(
            "This purchase belongs to a different Backword account."
        ))
        #expect(AccountEntitlementPresentation.linkedElsewhereExplanation.contains("not shared"))
        #expect(!AccountEntitlementPresentation.isAlreadyLinkedPurchaseError(
            "Apple transaction lookup failed (500)."
        ))
    }

    @Test("Signed-out account actions have clear copy")
    func signedOutAccountActionPresentation() {
        #expect(AccountSheetGuestAccessPresentation.pageTitle == "Sign in or create an account")
        #expect(AccountSheetGuestAccessPresentation.actionTitle == "Play as guest")
    }

    @Test("First account sync captures legacy guest release-day crossword points")
    func capturesLegacyGuestReleaseDayScore() {
        var rating = OverallRating()
        rating.upsertDailyCrossword(score: 3, date: "2026-08-09")
        var progress = UserProgress(
            puzzleId: "daily-9",
            size: 9,
            puzzleDate: "2026-08-09",
            totalClues: 21,
            isWeekly: false
        )
        progress.completedClueIds = [1]

        let migrated = AccountProgressMigration.captureGuestReleaseDateScores([progress], rating: rating)

        #expect(migrated.first?.completedClueIds == [1])
        #expect(migrated.first?.releaseDateScore == 3)
    }

    @Test("A migrated release-day score cannot be replaced by later archive progress")
    func retainsReleaseDayScoreDuringArchiveProgress() {
        var progress = UserProgress(
            puzzleId: "daily-9",
            size: 9,
            puzzleDate: "2026-08-09",
            totalClues: 21,
            isWeekly: false
        )
        progress.releaseDateScore = 1
        progress.completedClueIds = Set(1...21) // Later archive completion.

        #expect(progress.releaseDateScore == 1)
    }

    @Test("Existing account progress converts its saved aggregate score only once")
    func capturesExistingAccountLegacyScoreOnlyWhenSnapshotIsEmpty() {
        var rating = OverallRating()
        rating.upsertDailyCrossword(score: 2, date: "2026-08-12")
        var progress = UserProgress(
            puzzleId: "daily-12",
            size: 9,
            puzzleDate: "2026-08-12",
            totalClues: 22,
            isWeekly: false
        )

        let captured = AccountProgressMigration.captureGuestReleaseDateScores([progress], rating: rating)
        progress.releaseDateScore = captured[0].releaseDateScore
        rating.upsertDailyCrossword(score: 5, date: "2026-08-12")
        let preserved = AccountProgressMigration.captureGuestReleaseDateScores([progress], rating: rating)

        #expect(preserved[0].releaseDateScore == 2)
    }

    @Test("Legacy weekly points migrate without changing the saved grid")
    func capturesLegacyWeeklyScoreWithoutChangingProgress() {
        var rating = OverallRating()
        rating.upsertWeeklyCrossword(score: 4, date: "2026-08-09")
        var progress = UserProgress(
            puzzleId: "weekly-9",
            size: 13,
            puzzleDate: "2026-08-09",
            totalClues: 35,
            isWeekly: true
        )
        progress.completedClueIds = [4, 8, 15]
        progress.entries[0][0] = "A"

        let migrated = AccountProgressMigration.captureGuestReleaseDateScores([progress], rating: rating)

        #expect(migrated.first?.releaseDateScore == 4)
        #expect(migrated.first?.completedClueIds == [4, 8, 15])
        #expect(migrated.first?.entries[0][0] == "A")
    }

    @Test("A cloud grid conflict retains the higher release-day score")
    func crosswordConflictPreservesReleaseDayScore() {
        var local = UserProgress(puzzleId: "daily-9", size: 9, puzzleDate: "2026-08-09", totalClues: 21)
        local.completedClueIds = [1]
        local.releaseDateScore = 3

        var remote = UserProgress(puzzleId: "daily-9", size: 9, puzzleDate: "2026-08-09", totalClues: 21)
        remote.completedClueIds = [1, 2, 3]

        let reconciled = CloudProgressRanking.preservingReleaseDateScore(from: local, in: remote)

        #expect(reconciled.completedClueIds == [1, 2, 3])
        #expect(reconciled.releaseDateScore == 3)
    }
}
