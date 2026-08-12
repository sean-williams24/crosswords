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
}
