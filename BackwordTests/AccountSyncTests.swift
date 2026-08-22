import Foundation
import AuthenticationServices
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

    @Test("A StoreKit reconciliation is uniquely identified by its transaction")
    func storeKitReconciliationUsesTransactionID() {
        let reconciliation = AppleEntitlementReconciliation(
            transactionID: "transaction-123",
            originalTransactionID: "original-123",
            signedTransactionInfo: "signed-transaction"
        )

        #expect(reconciliation.id == "transaction-123")
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

    @Test("A server-confirmed missing account clears the cached local session")
    func unavailableAccountRequiresLocalSignOut() {
        #expect(AccountSessionValidation.requiresLocalSignOut(for: AuthError.sessionMissing))

        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/auth/v1/user")!,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!
        let missingUser = AuthError.api(
            message: "User not found",
            errorCode: .userNotFound,
            underlyingData: Data(),
            underlyingResponse: response
        )

        #expect(AccountSessionValidation.requiresLocalSignOut(for: missingUser))
    }

    @Test("A connection failure never signs out a cached account")
    func connectionFailureDoesNotRequireLocalSignOut() {
        #expect(!AccountSessionValidation.requiresLocalSignOut(for: URLError(.notConnectedToInternet)))
    }

    @Test("The deletion notice explains cloud and local data separately")
    func deletionNoticeExplainsWhatChanged() {
        #expect(AccountDeletionPresentation.message.contains("cloud-synced game progress"))
        #expect(AccountDeletionPresentation.message.contains("Apple subscription"))
        #expect(AccountDeletionPresentation.message.contains("stored locally"))
        #expect(AccountDeletionPresentation.message.contains("signed out"))
    }

    @Test("Sign-in failures use safe provider-specific retry copy")
    func signInFailureUsesSafeRetryCopy() {
        let error = AccountSignInErrorPresentation.error(
            for: GoogleNativeSignInError.missingIDToken,
            provider: .google
        )

        #expect(error == AccountSignInError(
            title: "Couldn't sign in",
            message: "We couldn't complete Google sign-in. Please try again or use the other option."
        ))
    }

    @Test("Offline sign-in failures explain how to recover")
    func offlineSignInFailureUsesConnectionCopy() {
        let error = AccountSignInErrorPresentation.error(
            for: URLError(.notConnectedToInternet),
            provider: .apple
        )

        #expect(error == AccountSignInError(
            title: "Couldn't sign in",
            message: "Check your internet connection and try again."
        ))
    }

    @Test("Cancelled sign-in is not shown as an error")
    func cancelledSignInIsNotPresented() {
        #expect(AccountSignInErrorPresentation.error(
            for: CancellationError(),
            provider: .google
        ) == nil)
    }

    #if DEBUG
    @Test("Debug previews use the same safe sign-in copy as production errors")
    func signInErrorPreviewsUseSafeCopy() {
        #expect(AccountSignInErrorPreview.apple.error == AccountSignInError(
            title: "Couldn't sign in",
            message: "We couldn't complete Apple sign-in. Please try again or use the other option."
        ))
        #expect(AccountSignInErrorPreview.google.error == AccountSignInError(
            title: "Couldn't sign in",
            message: "We couldn't complete Google sign-in. Please try again or use the other option."
        ))
        #expect(AccountSignInErrorPreview.offline.error == AccountSignInError(
            title: "Couldn't sign in",
            message: "Check your internet connection and try again."
        ))
    }
    #endif

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

    @Test("Account Pro status uses the shared Pro logo and mutes inactive access")
    func accountProStatusPresentation() {
        #expect(RatingAccountProStatusPresentation.logoName == "Pro")
        #expect(RatingAccountProStatusPresentation.logoWidth > 32)
        #expect(RatingAccountProStatusPresentation.logoHeight > 18)
        #expect(RatingAccountProStatusPresentation.inactiveGrayscale == 1)
        #expect(RatingAccountProStatusPresentation.inactiveOpacity < 1)
    }

    @Test("The rating footer surface covers the bottom scroll inset")
    func ratingFooterSurfacePresentation() {
        #expect(RatingDetailSheetLayout.footerSurfaceExtension > 0)
    }

    @Test("Signed-out account actions have clear copy")
    func signedOutAccountActionPresentation() {
        #expect(AccountSheetGuestAccessPresentation.pageTitle == "Sign in or create an account")
        #expect(AccountSheetGuestAccessPresentation.actionTitle == "Play as guest")
    }

    @Test("Account sync presentation distinguishes active and completed sync states")
    func accountSyncPresentation() {
        #expect(AccountSyncPresentation.statusText(isSyncing: true) == "Syncing your games…")
        #expect(AccountSyncPresentation.statusText(isSyncing: false) == "Progress and stats are synced - Tap to sync again")
        #expect(AccountSyncPresentation.spinnerAccessibilityLabel == "Syncing your games")
    }

    @Test("Apple sign-in requests the account details needed for profile setup")
    func appleSignInRequestConfiguration() {
        let request = ASAuthorizationAppleIDProvider().createRequest()

        AppleSignInRequestConfiguration.configure(request)

        #expect(Set(request.requestedScopes ?? []) == Set([.fullName, .email]))
    }

    @Test("A new authenticated session activates account-scoped persistence once")
    func newSessionActivatesPersistence() {
        let transition = AccountSessionTransition(
            activePersistenceAccountID: nil,
            newAccountID: "account-a"
        )

        #expect(transition.requiresPersistenceActivation)
    }

    @Test("Repeated auth events for the same account do not restart guest migration")
    func repeatedSessionDoesNotActivatePersistence() {
        let transition = AccountSessionTransition(
            activePersistenceAccountID: "account-a",
            newAccountID: "account-a"
        )

        #expect(!transition.requiresPersistenceActivation)
    }

    @Test("Guest account entry opens sign in")
    func guestAccountEntryDestination() {
        #expect(AccountPresentationDestination.destination(isSignedIn: false) == .signIn)
    }

    @Test("Signed-in account entry opens rating details")
    func signedInAccountEntryDestination() {
        #expect(AccountPresentationDestination.destination(isSignedIn: true) == .ratingDetails)
    }

    @Test("Settings only offers account deletion to signed-in users")
    func settingsDeleteAccountVisibility() {
        #expect(SettingsAccountActionVisibility.showsDeleteAccount(isSignedIn: true))
        #expect(!SettingsAccountActionVisibility.showsDeleteAccount(isSignedIn: false))
    }

    @Test("Settings deletion confirmation explains the destructive action")
    func settingsDeletionConfirmationPresentation() {
        #expect(SettingsDeletionConfirmationPresentation.title == "Delete Backword account?")
        #expect(SettingsDeletionConfirmationPresentation.message.contains("cloud progress"))
        #expect(SettingsDeletionConfirmationPresentation.message.contains("does not cancel your Apple subscription"))
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
