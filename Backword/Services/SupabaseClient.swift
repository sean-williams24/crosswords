//  SupabaseClient.swift

import AuthenticationServices
import Foundation
import OSLog
import StoreKit
import Supabase

protocol SupabaseClientProtocol {
    func fetchTodaysBackword() async throws -> BackwordWord
    func fetchBackwordArchive() async throws -> [BackwordWord]
    func fetchBackwordArchiveMonths() async throws -> [ArchiveMonth]
    func fetchBackwords(for month: ArchiveMonth) async throws -> [BackwordWord]
}

/// Converts a Supabase Edge Function failure into the safe diagnostic message
/// returned by our server. This lets an account holder act on a bad Apple API
/// configuration without exposing transaction data in the app.
enum AccountFunctionError {
    static func message(for error: Error) -> String {
        guard case let FunctionsError.httpError(code, data) = error else {
            return error.localizedDescription
        }

        let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let body, !body.isEmpty {
            return body
        }
        return "Subscription linking failed (server returned \(code))."
    }
}

enum AccountFunctionRequest {
    /// Edge Functions that mutate account-owned data must use the current
    /// Supabase session token, rather than the public project key.
    static func authenticatedHeaders(accessToken: String) -> [String: String] {
        ["Authorization": "Bearer \(accessToken)"]
    }
}

enum AccountErrorPresentation {
    /// SwiftUI cancels view-scoped tasks when their view is replaced or
    /// dismissed. That is expected control flow, not an account failure.
    static func shouldPresent(_ error: Error, taskIsCancelled: Bool = Task.isCancelled) -> Bool {
        !taskIsCancelled && !(error is CancellationError)
    }
}

/// A cached session is not proof that its account still exists. The app checks
/// the Auth user endpoint before syncing, and only clears local state when the
/// server has explicitly rejected that session or user.
enum AccountSessionValidation {
    static func requiresLocalSignOut(for error: Error) -> Bool {
        guard let authError = error as? AuthError else { return false }

        switch authError {
        case .sessionMissing:
            return true
        case let .api(_, errorCode, _, response):
            return errorCode == .userNotFound || [401, 404].contains(response.statusCode)
        default:
            return false
        }
    }
}

enum AccountDeletionPresentation {
    static let title = "Your Backword account was deleted"
    static let message = "Your Backword account, cloud-synced game progress, stats, and rating were deleted. This device has been signed out and is now playing as a guest. Your Apple subscription and game data stored locally on this device were not deleted."
}

enum AccountSignInProvider: Equatable {
    case apple
    case google

    var name: String {
        switch self {
        case .apple: "Apple"
        case .google: "Google"
        }
    }
}

struct AccountSignInError: Equatable {
    let title: String
    let message: String
}

/// Maps provider and network failures to safe, actionable sign-in copy. The
/// underlying error is still logged by AccountService for diagnosis.
enum AccountSignInErrorPresentation {
    static let title = "Couldn't sign in"
    static let offlineMessage = "Check your internet connection and try again."

    static func error(for error: Error, provider: AccountSignInProvider) -> AccountSignInError? {
        guard shouldPresent(error) else { return nil }

        if isOffline(error) {
            return AccountSignInError(title: title, message: offlineMessage)
        }

        return AccountSignInError(
            title: title,
            message: "We couldn't complete \(provider.name) sign-in. Please try again or use the other option."
        )
    }

    private static func shouldPresent(_ error: Error) -> Bool {
        guard AccountErrorPresentation.shouldPresent(error) else { return false }
        let nsError = error as NSError
        return !isAppleCancellation(nsError) && !isGoogleCancellation(nsError)
    }

    private static func isOffline(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    private static func isAppleCancellation(_ error: NSError) -> Bool {
        error.domain == ASAuthorizationError.errorDomain
            && error.code == ASAuthorizationError.canceled.rawValue
    }

    private static func isGoogleCancellation(_ error: NSError) -> Bool {
        // Google Sign-In reports a user-dismissed account picker with this
        // documented domain/code pair. It is expected interaction, not an error.
        error.domain == "com.google.GIDSignIn" && error.code == -5
    }
}

private enum AccountSignInInputError: Error {
    case missingAppleCredential
}

#if DEBUG
enum AccountSignInErrorPreview: CaseIterable {
    case apple
    case google
    case offline

    var error: AccountSignInError {
        switch self {
        case .apple:
            AccountSignInError(
                title: AccountSignInErrorPresentation.title,
                message: "We couldn't complete Apple sign-in. Please try again or use the other option."
            )
        case .google:
            AccountSignInError(
                title: AccountSignInErrorPresentation.title,
                message: "We couldn't complete Google sign-in. Please try again or use the other option."
            )
        case .offline:
            AccountSignInError(
                title: AccountSignInErrorPresentation.title,
                message: AccountSignInErrorPresentation.offlineMessage
            )
        }
    }
}
#endif

final class SupabaseClient: SupabaseClientProtocol {
    static let shared = SupabaseClient()
    private let dateFormatting = DateFormatting()
    let client: Supabase.SupabaseClient
    private let baseURL = Secrets.supabaseURL
    private let apiKey = Secrets.supabaseAnonKey

    init() {
        self.client = Supabase.SupabaseClient(supabaseURL: URL(string: baseURL)!, supabaseKey: apiKey)
    }

    func fetchTodaysBackword() async throws -> BackwordWord {
        let row: BackwordRow = try await client
            .from("backword_words")
            .select()
            .eq("date", value: today)
            .single()
            .execute()
            .value

        return row.toBackwordWord
    }

    func fetchBackwordArchive() async throws -> [BackwordWord] {
        let rows: [BackwordRow] = try await client
            .from("backword_words")
            .select()
            .lte("date", value: today)       // Equivalent to date=lte.\(today)
            .order("date", ascending: false) // Equivalent to order=date.desc
            .limit(90)                       // Equivalent to limit=90
            .execute()
            .value

        return rows.map { $0.toBackwordWord }
    }

    func fetchBackwordArchiveMonths() async throws -> [ArchiveMonth] {
        let rows: [BackwordDateRow] = try await client
            .from("backword_words")
            .select("date")
            .lte("date", value: today)
            .order("date", ascending: false)
            .execute()
            .value

        return Array(Set(rows.compactMap { ArchiveMonth.from(dateString: $0.date) })).sorted(by: >)
    }

    func fetchBackwords(for month: ArchiveMonth) async throws -> [BackwordWord] {
        let range = month.dateRange()
        let upperBound = min(range.upperBound, today)
        guard range.lowerBound <= upperBound else { return [] }

        let rows: [BackwordRow] = try await client
            .from("backword_words")
            .select()
            .gte("date", value: range.lowerBound)
            .lte("date", value: upperBound)
            .order("date", ascending: false)
            .execute()
            .value

        return rows.map { $0.toBackwordWord }
    }

    private var today: String {
        dateFormatting.todayString()
    }
}

// MARK: - Account session

@MainActor
final class AccountService: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var isLoading = true
    @Published private(set) var isSyncing = false
    @Published private(set) var isProUser = false
    @Published private(set) var proExpirationDate: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var signInError: AccountSignInError?
    @Published private(set) var localProLinkedElsewhere = false
    @Published private(set) var syncRevision = 0
    @Published private(set) var accountDeletionNotice: String?

    private let client: Supabase.SupabaseClient
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Backword",
        category: "account"
    )
    private var authStateTask: Task<Void, Never>?
    private var accountRefreshTask: (id: UUID, task: Task<Void, Never>)?
    private var pendingGuestBackword: [BackwordProgress] = []
    private var pendingGuestCrosswords: [UserProgress] = []

    private struct AppleEntitlementClaimRequest: Encodable {
        let transactionID: String
        let originalTransactionID: String
        let signedTransactionInfo: String
    }

    init(client: Supabase.SupabaseClient = SupabaseClient.shared.client) {
        self.client = client
        session = client.auth.currentSession
        activateProgressPersistence(for: session)
        isLoading = false
        observeAuthState()
        Task { await refreshAccountData() }
    }

    deinit {
        authStateTask?.cancel()
        accountRefreshTask?.task.cancel()
    }

    var userID: UUID? { session?.user.id }
    var email: String? { session?.user.email }
    var isSignedIn: Bool { session != nil }
    var purchaseAccountToken: UUID? { userID }

    @discardableResult
    func signInWithApple(idToken: String, fullName: PersonNameComponents?) async -> Bool {
        await performAuthentication(provider: .apple) {
            _ = try await self.client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
            if let fullName, !fullName.formatted().isEmpty {
                _ = try? await self.client.auth.update(
                    user: UserAttributes(data: ["full_name": .string(fullName.formatted())])
                )
            }
        }
    }

    @discardableResult
    func signInWithGoogle() async -> Bool {
        await performAuthentication(provider: .google) {
            let idToken = try await GoogleNativeSignInService.shared.signIn()
            _ = try await self.client.auth.signInWithIdToken(
                credentials: .init(provider: .google, idToken: idToken)
            )
        }
    }

    func recordAppleSignInFailure(_ error: Error? = nil) {
        let failure = error ?? AccountSignInInputError.missingAppleCredential
        presentSignInError(failure, provider: .apple)
    }

    #if DEBUG
    func setDebugSignInErrorPreview(_ preview: AccountSignInErrorPreview?) {
        signInError = preview?.error
    }
    #endif

    /// Completes browser-based Supabase auth redirects. Native Apple and Google
    /// sign-in exchange their identity tokens directly and do not use this path.
    func handleAuthRedirect(_ url: URL) async {
        guard url.scheme == Self.redirectURL.scheme else { return }
        do {
            _ = try await client.auth.session(from: url)
        } catch {
            presentError(error, operation: "auth redirect")
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            session = nil
            activateProgressPersistence(for: nil)
            isProUser = false
            proExpirationDate = nil
            localProLinkedElsewhere = false
            errorMessage = nil
        } catch {
            presentError(error, operation: "sign out")
        }
    }

    func deleteAccount() async -> Bool {
        do {
            try await client.functions.invoke("delete-account")
            // The delete endpoint may already revoke the current session.
            // Clearing local account state must still succeed in that case.
            try? await client.auth.signOut()
            session = nil
            activateProgressPersistence(for: nil)
            isProUser = false
            proExpirationDate = nil
            localProLinkedElsewhere = false
            accountDeletionNotice = AccountDeletionPresentation.message
            return true
        } catch {
            presentError(error, operation: "account deletion")
            return false
        }
    }

    func dismissAccountDeletionNotice() {
        accountDeletionNotice = nil
    }

    func refreshAccountData() async {
        if let accountRefreshTask {
            await accountRefreshTask.task.value
            return
        }

        let guestBackword = pendingGuestBackword
        let guestCrosswords = pendingGuestCrosswords
        pendingGuestBackword = []
        pendingGuestCrosswords = []
        let refreshID = UUID()
        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await self.performAccountRefresh(
                guestBackword: guestBackword,
                guestCrosswords: guestCrosswords
            )
        }
        accountRefreshTask = (id: refreshID, task: task)
        await task.value

        // A caller that was waiting on an earlier task must not clear a
        // refresh that started after it resumed.
        if accountRefreshTask?.id == refreshID {
            accountRefreshTask = nil
        }
    }

    private func performAccountRefresh(
        guestBackword: [BackwordProgress],
        guestCrosswords: [UserProgress]
    ) async {
        guard session != nil else {
            isProUser = false
            proExpirationDate = nil
            return
        }

        do {
            _ = try await client.auth.user()
        } catch {
            if AccountSessionValidation.requiresLocalSignOut(for: error) {
                await clearUnavailableAccountSession()
            } else if AccountErrorPresentation.shouldPresent(error) {
                logger.error("Account session validation could not reach the server: \(error.localizedDescription, privacy: .public)")
            }
            return
        }

        errorMessage = nil
        isSyncing = true
        defer { isSyncing = false }
        if let accountID = userID {
            await ProgressCloudSync.shared.sync(
                accountID: accountID.uuidString,
                guestBackword: guestBackword,
                guestCrosswords: guestCrosswords
            )
            syncRevision &+= 1
        }
        await claimCurrentAppleEntitlements()
        await refreshProEntitlement()
    }

    /// Existing subscribers can attach a verified current StoreKit transaction
    /// after they create an account. The Edge Function validates the data with
    /// Apple before it creates the account association.
    func claimCurrentAppleEntitlements() async {
        guard isSignedIn else { return }

        let accessToken: String
        do {
            // Ask Auth for the current token so a token refresh is reflected
            // in this protected Function request immediately.
            accessToken = try await client.auth.session.accessToken
        } catch {
            guard AccountErrorPresentation.shouldPresent(error) else { return }
            logger.error("Account entitlement claim could not read the current session: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your account session has expired. Please sign in again."
            return
        }

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  StoreService.grantsProAccess(
                    productID: transaction.productID,
                    revocationDate: transaction.revocationDate,
                    expirationDate: transaction.expirationDate
                  ) else { continue }

            let request = AppleEntitlementReconciliation(
                transactionID: String(transaction.id),
                originalTransactionID: String(transaction.originalID),
                // The signed JWS belongs to StoreKit's verification result,
                // rather than the unwrapped Transaction payload.
                signedTransactionInfo: result.jwsRepresentation
            )
            await claimAppleEntitlement(request, accessToken: accessToken)
        }
    }

    /// Reconciles a verified StoreKit revocation immediately instead of waiting
    /// for a later profile refresh or an App Store Server Notification delivery.
    func reconcileAppleEntitlement(_ reconciliation: AppleEntitlementReconciliation) async {
        guard isSignedIn else { return }

        let accessToken: String
        do {
            accessToken = try await client.auth.session.accessToken
        } catch {
            guard AccountErrorPresentation.shouldPresent(error) else { return }
            logger.error("Account entitlement reconciliation could not read the current session: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Your account session has expired. Please sign in again."
            return
        }

        await claimAppleEntitlement(reconciliation, accessToken: accessToken)
        await refreshProEntitlement()
    }

    private func claimAppleEntitlement(
        _ reconciliation: AppleEntitlementReconciliation,
        accessToken: String
    ) async {
        let request = AppleEntitlementClaimRequest(
            transactionID: reconciliation.transactionID,
            originalTransactionID: reconciliation.originalTransactionID,
            signedTransactionInfo: reconciliation.signedTransactionInfo
        )

        do {
            try await client.functions.invoke(
                "claim-apple-entitlement",
                options: FunctionInvokeOptions(
                    headers: AccountFunctionRequest.authenticatedHeaders(accessToken: accessToken),
                    body: request
                )
            )
            localProLinkedElsewhere = false
        } catch {
            // A failed reconciliation must not prevent local StoreKit access.
            // The account sheet keeps the server's safe diagnostic available
            // to retry or correct Apple API configuration.
            let message = AccountFunctionError.message(for: error)
            localProLinkedElsewhere = AccountEntitlementPresentation.isAlreadyLinkedPurchaseError(message)
            presentError(error, operation: "Apple entitlement claim", message: message)
        }
    }

    private func refreshProEntitlement() async {
        struct Entitlement: Decodable {
            let isPro: Bool
            let expiresAt: Date?

            enum CodingKeys: String, CodingKey {
                case isPro = "is_pro"
                case expiresAt = "expires_at"
            }
        }

        do {
            let result: [Entitlement] = try await client
                .rpc("current_user_pro_entitlement")
                .execute()
                .value
            let entitlement = result.first
            isProUser = entitlement?.isPro ?? false
            proExpirationDate = entitlement?.expiresAt
        } catch {
            presentError(error, operation: "account Pro entitlement refresh")
        }
    }

    private func observeAuthState() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await (_, newSession) in client.auth.authStateChanges {
                self.applySession(newSession)
                self.refreshAccountDataInBackground()
            }
        }
    }

    private func performAuthentication(
        provider: AccountSignInProvider,
        _ action: @escaping @Sendable () async throws -> Void
    ) async -> Bool {
        isLoading = true
        signInError = nil
        defer { isLoading = false }
        do {
            try await action()
            // The authenticated session is enough to leave the sign-in sheet.
            // Progress migration, cloud reconciliation, and entitlements are
            // deliberately non-blocking and update the rating surface when done.
            applySession(client.auth.currentSession)
            refreshAccountDataInBackground()
            return true
        } catch {
            presentSignInError(error, provider: provider)
            return false
        }
    }

    private func presentSignInError(_ error: Error, provider: AccountSignInProvider) {
        guard let presentation = AccountSignInErrorPresentation.error(for: error, provider: provider) else {
            return
        }
        logger.error("Account \(provider.name, privacy: .public) sign-in failed: \(error.localizedDescription, privacy: .public)")
        signInError = presentation
    }

    private func presentError(_ error: Error, operation: String, message: String? = nil) {
        guard AccountErrorPresentation.shouldPresent(error) else { return }
        let displayedMessage = message ?? error.localizedDescription
        logger.error("Account \(operation, privacy: .public) failed: \(displayedMessage, privacy: .public)")
        errorMessage = displayedMessage
    }

    private static let redirectURL = URL(string: "backword://login-callback")!

    private func applySession(_ newSession: Session?) {
        let accountID = newSession?.user.id.uuidString
        let transition = AccountSessionTransition(
            activePersistenceAccountID: ProgressStorageNamespace.accountID,
            newAccountID: accountID
        )
        session = newSession
        errorMessage = nil
        signInError = nil
        if newSession == nil {
            isProUser = false
            proExpirationDate = nil
            localProLinkedElsewhere = false
        }
        guard transition.requiresPersistenceActivation else { return }
        activateProgressPersistence(for: newSession)
    }

    private func clearUnavailableAccountSession() async {
        // The server has already rejected the account, so local sign-out is
        // sufficient and must not depend on a successful logout response.
        try? await client.auth.signOut(scope: .local)
        applySession(nil)
        accountDeletionNotice = AccountDeletionPresentation.message
    }

    private func refreshAccountDataInBackground() {
        Task { [weak self] in
            await self?.refreshAccountData()
        }
    }

    private func activateProgressPersistence(for newSession: Session?) {
        let isMigratingGuestProgress = ProgressStorageNamespace.accountID == nil && newSession != nil
        let guestBackword = isMigratingGuestProgress ? BackwordProgress.loadAll() : []
        let guestCrosswords = isMigratingGuestProgress
            ? AccountProgressMigration.captureGuestReleaseDateScores(UserProgress.loadAll(), rating: OverallRating.load())
            : []
        ProgressStorageNamespace.activate(accountID: newSession?.user.id.uuidString)
        pendingGuestBackword = guestBackword
        pendingGuestCrosswords = guestCrosswords
    }

}

struct AccountSessionTransition: Equatable {
    let activePersistenceAccountID: String?
    let newAccountID: String?

    var requiresPersistenceActivation: Bool {
        activePersistenceAccountID != newAccountID
    }
}

enum AccountProgressMigration {
    /// Old guest builds kept release-window points only in OverallRating. On
    /// first account sign-in, copy those values onto the real puzzle records
    /// before upload so progress and score travel together from then on.
    static func captureGuestReleaseDateScores(
        _ progressRecords: [UserProgress],
        rating: OverallRating
    ) -> [UserProgress] {
        progressRecords.map { captureLegacyReleaseDateScore(in: $0, rating: rating) }
    }

    /// Converts an older account-local aggregate into snapshots before that
    /// aggregate is discarded. Only empty snapshots are filled: once a score
    /// is captured, later Archive play cannot alter it.
    @discardableResult
    static func persistLegacyReleaseDateScores(
        in progressRecords: [UserProgress],
        rating: OverallRating
    ) -> [UserProgress] {
        progressRecords.map { progress in
            let captured = captureLegacyReleaseDateScore(in: progress, rating: rating)
            if captured.releaseDateScore != progress.releaseDateScore {
                captured.save()
            }
            return captured
        }
    }

    private static func captureLegacyReleaseDateScore(
        in progress: UserProgress,
        rating: OverallRating
    ) -> UserProgress {
        guard progress.releaseDateScore == 0,
              let date = progress.puzzleDate else { return progress }
        var captured = progress
        let category: RatingGameCategory = progress.isWeekly == true ? .weeklyCrossword : .dailyCrossword
        captured.releaseDateScore = rating.score(for: category, date: date)
        return captured
    }
}

// MARK: - Cloud progress

@MainActor
final class ProgressCloudSync {
    static let shared = ProgressCloudSync()

    private let client = SupabaseClient.shared.client
    private let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        // JavaScript's Date#toISOString always includes milliseconds, so the
        // shared payload needs fractional-second parsing on iOS as well.
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter
    }()
    private var scheduledUploadTask: Task<Void, Never>?
    private var pendingBackword: [String: BackwordProgress] = [:]
    private var pendingCrosswords: [String: UserProgress] = [:]

    private init() {}

    func scheduleUpload(_ progress: BackwordProgress) {
        guard ProgressStorageNamespace.accountID != nil else { return }
        pendingBackword[progress.date] = progress
        scheduleFlush(immediately: progress.isComplete)
    }

    func scheduleUpload(_ progress: UserProgress) {
        guard ProgressStorageNamespace.accountID != nil else { return }
        pendingCrosswords[progress.puzzleId] = progress
        scheduleFlush(immediately: progress.isComplete || progress.gaveUpAt != nil)
    }

    /// Called when the app backgrounds and before a full pull. Failed records
    /// intentionally stay in these account-scoped local files and are retried
    /// on the next foreground/connection sync.
    func flushPendingUploads() async {
        scheduledUploadTask = nil

        let backword = pendingBackword
        let crosswords = pendingCrosswords
        for progress in backword.values {
            if await upload(progress) {
                pendingBackword.removeValue(forKey: progress.date)
            }
        }
        for progress in crosswords.values {
            if await upload(progress) {
                pendingCrosswords.removeValue(forKey: progress.puzzleId)
            }
        }
    }

    func sync(accountID: String, guestBackword: [BackwordProgress], guestCrosswords: [UserProgress]) async {
        guard ProgressStorageNamespace.accountID == accountID else { return }
        await flushPendingUploads()
        // Flush any account-scoped local records that were saved while offline
        // before pulling the server's winning records.
        _ = await mergeBackword(BackwordProgress.loadAll())
        _ = await mergeCrosswords(UserProgress.loadAll())
        let uploadedBackword = await mergeBackword(guestBackword)
        let uploadedCrosswords = await mergeCrosswords(guestCrosswords)
        await pullBackword()
        await pullCrosswords()
        removeSuccessfullyMigratedGuestProgress(
            backwordDates: uploadedBackword,
            crosswordIDs: uploadedCrosswords,
            activeAccountID: accountID
        )
    }

    private func scheduleFlush(immediately: Bool) {
        scheduledUploadTask?.cancel()
        scheduledUploadTask = Task { [weak self] in
            if !immediately {
                try? await Task.sleep(for: .milliseconds(700))
            }
            guard !Task.isCancelled else { return }
            await self?.flushPendingUploads()
        }
    }

    private func mergeBackword(_ guestProgress: [BackwordProgress]) async -> Set<String> {
        var uploaded = Set<String>()
        for progress in guestProgress {
            if await upload(progress) { uploaded.insert(progress.date) }
        }
        return uploaded
    }

    private func mergeCrosswords(_ guestProgress: [UserProgress]) async -> Set<String> {
        var uploaded = Set<String>()
        for progress in guestProgress {
            if await upload(progress) { uploaded.insert(progress.puzzleId) }
        }
        return uploaded
    }

    @discardableResult
    private func upload(_ progress: BackwordProgress) async -> Bool {
        let payload = CloudBackwordPayload(progress, formatter: iso8601)
        let request = MergeProgressRequest(
            gameType: "backword",
            contentKey: progress.date,
            releaseDate: progress.date,
            status: payload.status,
            progressRank: progress.guesses.count,
            releaseScore: progress.completedScore ?? 0,
            clientUpdatedAt: payload.updatedAt,
            payload: payload
        )
        do {
            try await client.rpc("merge_game_progress", params: request).execute()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    private func upload(_ progress: UserProgress) async -> Bool {
        guard let releaseDate = progress.puzzleDate else { return false }
        let payload = CloudCrosswordPayload(progress, formatter: iso8601)
        let status = progress.gaveUpAt != nil ? "gave_up" : (progress.isComplete ? "solved" : "in_progress")
        let rank = progress.completedClueIds.count * 100 + progress.entries.flatMap { $0 }.compactMap { $0 }.count
        let request = MergeProgressRequest(
            gameType: progress.isWeekly == true ? "weekly_crossword" : "daily_crossword",
            contentKey: progress.puzzleId,
            releaseDate: releaseDate,
            status: status,
            progressRank: rank,
            releaseScore: payload.releaseDateScore,
            clientUpdatedAt: payload.updatedAt,
            payload: payload
        )
        do {
            try await client.rpc("merge_game_progress", params: request).execute()
            return true
        } catch {
            return false
        }
    }

    private func pullBackword() async {
        guard let rows: [CloudProgressRow<CloudBackwordPayload>] = try? await client
            .from("game_progress")
            .select()
            .eq("game_type", value: "backword")
            .execute()
            .value else { return }

        for row in rows {
            let remote = row.payload.progress(formatter: iso8601)
            guard let remote else { continue }
            if let local = BackwordProgress.load(date: remote.date),
               !CloudProgressRanking.shouldReplace(local: local, with: remote, formatter: iso8601) {
                await upload(local)
            } else {
                remote.save()
            }
        }
    }

    private func pullCrosswords() async {
        for gameType in ["daily_crossword", "weekly_crossword"] {
            guard let rows: [CloudProgressRow<CloudCrosswordPayload>] = try? await client
                .from("game_progress")
                .select()
                .eq("game_type", value: gameType)
                .execute()
                .value else { continue }

            for row in rows {
                guard let decodedRemote = row.payload.progress(formatter: iso8601) else { continue }
                if let storedLocal = UserProgress.load(puzzleId: decodedRemote.puzzleId) {
                    let remote = CloudProgressRanking.preservingReleaseDateScore(
                        from: storedLocal,
                        in: decodedRemote
                    )
                    let local = CloudProgressRanking.preservingReleaseDateScore(
                        from: decodedRemote,
                        in: storedLocal
                    )
                    if local.releaseDateScore != storedLocal.releaseDateScore {
                        local.save()
                    }
                    if !CloudProgressRanking.shouldReplace(local: local, with: remote, formatter: iso8601) {
                        await upload(local)
                    } else {
                        remote.save()
                        // The server's grid won, but a local device may hold
                        // an earned release-day score from before snapshots
                        // existed. Upload the promoted snapshot immediately.
                        if remote.releaseDateScore != decodedRemote.releaseDateScore {
                            await upload(remote)
                        }
                    }
                } else {
                    decodedRemote.save()
                }
            }
        }
    }

    private func removeSuccessfullyMigratedGuestProgress(
        backwordDates: Set<String>,
        crosswordIDs: Set<String>,
        activeAccountID: String
    ) {
        guard !backwordDates.isEmpty || !crosswordIDs.isEmpty else { return }
        ProgressStorageNamespace.activate(accountID: nil)
        for date in backwordDates { BackwordProgress.delete(date: date) }
        for puzzleID in crosswordIDs { UserProgress.delete(puzzleId: puzzleID) }
        ProgressStorageNamespace.activate(accountID: activeAccountID)
    }
}

private struct MergeProgressRequest<Payload: Encodable>: Encodable {
    let gameType: String
    let contentKey: String
    let releaseDate: String
    let status: String
    let progressRank: Int
    let releaseScore: Int
    let clientUpdatedAt: String
    let payload: Payload

    enum CodingKeys: String, CodingKey {
        case gameType = "p_game_type"
        case contentKey = "p_content_key"
        case releaseDate = "p_release_date"
        case status = "p_status"
        case progressRank = "p_progress_rank"
        case releaseScore = "p_release_score"
        case clientUpdatedAt = "p_client_updated_at"
        case payload = "p_payload"
        case schemaVersion = "p_schema_version"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gameType, forKey: .gameType)
        try container.encode(contentKey, forKey: .contentKey)
        try container.encode(releaseDate, forKey: .releaseDate)
        try container.encode(1, forKey: .schemaVersion)
        try container.encode(status, forKey: .status)
        try container.encode(progressRank, forKey: .progressRank)
        try container.encode(releaseScore, forKey: .releaseScore)
        try container.encode(clientUpdatedAt, forKey: .clientUpdatedAt)
        try container.encode(payload, forKey: .payload)
    }
}

private struct CloudProgressRow<Payload: Decodable>: Decodable {
    let payload: Payload
}

private struct CloudBackwordPayload: Codable {
    let schemaVersion: Int
    let date: String
    let guesses: [String]
    let outcome: String
    let completedAt: String?
    let updatedAt: String

    init(_ progress: BackwordProgress, formatter: ISO8601DateFormatter) {
        schemaVersion = 1
        date = progress.date
        guesses = progress.guesses
        // Keep the payload vocabulary shared with the website. The database
        // status remains snake_case, but the user-facing payload is camelCase.
        outcome = progress.isWon ? "won" : (progress.isFailed ? "failed" : "inProgress")
        completedAt = progress.completedAt.map { formatter.string(from: $0) }
        updatedAt = formatter.string(from: progress.updatedAt)
    }

    func progress(formatter: ISO8601DateFormatter) -> BackwordProgress? {
        var progress = BackwordProgress(date: date)
        progress.guesses = guesses
        progress.completedAt = completedAt.flatMap { formatter.date(from: $0) }
        progress.wonFlag = outcome == "won"
        progress.updatedAt = formatter.date(from: updatedAt) ?? progress.completedAt ?? Date()
        return progress
    }

    var status: String {
        outcome == "won" ? "solved" : (outcome == "failed" ? "failed" : "in_progress")
    }
}

private struct CloudCrosswordPayload: Codable {
    let schemaVersion: Int
    let puzzleId: String
    /// Shared web/iOS field names. Extra native fields below preserve iOS
    /// completion and hint detail without preventing web clients from reading
    /// the canonical grid record.
    let date: String
    let size: Int
    let entries: [[String?]]
    let completedClueIds: [Int]
    let hintedClueIds: [Int]?
    let hintsUsed: Int?
    let startedAt: String
    let completedAt: String?
    let totalClues: Int?
    let isWeekly: Bool?
    let gaveUpAt: String?
    let gaveUpScore: Int?
    let gaveUpRevealedCells: [String]?
    let releaseDateScore: Int
    let updatedAt: String

    init(_ progress: UserProgress, formatter: ISO8601DateFormatter) {
        schemaVersion = 1
        puzzleId = progress.puzzleId
        date = progress.puzzleDate ?? ""
        size = progress.entries.count
        entries = progress.entries
        completedClueIds = Array(progress.completedClueIds)
        hintedClueIds = Array(progress.hintedClueIds)
        hintsUsed = progress.hintsUsed
        startedAt = formatter.string(from: progress.startedAt)
        completedAt = progress.completedAt.map { formatter.string(from: $0) }
        totalClues = progress.totalClues
        isWeekly = progress.isWeekly
        gaveUpAt = progress.gaveUpAt.map { formatter.string(from: $0) }
        gaveUpScore = progress.gaveUpScore
        gaveUpRevealedCells = Array(progress.gaveUpRevealedCells)
        releaseDateScore = progress.releaseDateScore
        updatedAt = formatter.string(from: progress.updatedAt)
    }

    func progress(formatter: ISO8601DateFormatter) -> UserProgress? {
        guard let started = formatter.date(from: startedAt) else { return nil }
        return UserProgress(
            puzzleId: puzzleId,
            entries: entries,
            completedClueIds: Set(completedClueIds),
            hintedClueIds: Set(hintedClueIds ?? []),
            hintsUsed: hintsUsed ?? 0,
            startedAt: started,
            completedAt: completedAt.flatMap { formatter.date(from: $0) },
            puzzleDate: date,
            totalClues: totalClues,
            isWeekly: isWeekly,
            gaveUpAt: gaveUpAt.flatMap { formatter.date(from: $0) },
            gaveUpScore: gaveUpScore,
            gaveUpRevealedCells: Set(gaveUpRevealedCells ?? []),
            releaseDateScore: releaseDateScore,
            updatedAt: formatter.date(from: updatedAt) ?? completedAt.flatMap { formatter.date(from: $0) } ?? started
        )
    }
}

enum CloudProgressRanking {
    static func shouldReplace(local: BackwordProgress, with remote: BackwordProgress, formatter: ISO8601DateFormatter) -> Bool {
        if remote.isWon != local.isWon { return remote.isWon }
        if remote.isComplete != local.isComplete { return remote.isComplete }
        if remote.isWon, local.isWon, remote.guesses.count != local.guesses.count {
            return remote.guesses.count < local.guesses.count
        }
        if remote.guesses.count != local.guesses.count { return remote.guesses.count > local.guesses.count }
        return remote.updatedAt > local.updatedAt
    }

    static func shouldReplace(local: UserProgress, with remote: UserProgress, formatter: ISO8601DateFormatter) -> Bool {
        let localSolved = local.isComplete && local.gaveUpAt == nil
        let remoteSolved = remote.isComplete && remote.gaveUpAt == nil
        if localSolved != remoteSolved { return remoteSolved }
        let localTerminal = local.isComplete || local.gaveUpAt != nil
        let remoteTerminal = remote.isComplete || remote.gaveUpAt != nil
        if localTerminal != remoteTerminal { return remoteTerminal }
        if local.completedClueIds.count != remote.completedClueIds.count {
            return remote.completedClueIds.count > local.completedClueIds.count
        }
        let localFilled = local.entries.flatMap { $0 }.compactMap { $0 }.count
        let remoteFilled = remote.entries.flatMap { $0 }.compactMap { $0 }.count
        if localFilled != remoteFilled { return remoteFilled > localFilled }
        return remote.updatedAt > local.updatedAt
    }

    /// Crosswords keep their grids as whole records, while release-day points
    /// are a separate immutable historical fact. Preserve that fact before a
    /// local conflict winner is uploaded or saved.
    static func preservingReleaseDateScore(from source: UserProgress, in target: UserProgress) -> UserProgress {
        guard source.releaseDateScore > target.releaseDateScore else { return target }
        var result = target
        result.releaseDateScore = source.releaseDateScore
        return result
    }
}

private struct BackwordDateRow: Decodable {
    let date: String
}
