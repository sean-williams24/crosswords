@MainActor
final class AdConsentCoordinator {
    private let consentService: AdConsentPreparing
    private var statusRefreshTask: Task<Bool, Never>?
    private var hasRefreshedStatus = false

    init(consentService: AdConsentPreparing) {
        self.consentService = consentService
    }

    var isPrivacyOptionsRequired: Bool {
        consentService.isPrivacyOptionsRequired
    }

    @discardableResult
    func refreshStatusIfNeeded() async -> Bool {
        if hasRefreshedStatus { return true }
        if let statusRefreshTask { return await statusRefreshTask.value }

        let task = Task { await consentService.updateConsentInfo() }
        statusRefreshTask = task
        let didRefresh = await task.value
        // An offline launch must remain retryable when the player requests a hint.
        hasRefreshedStatus = didRefresh
        statusRefreshTask = nil
        return didRefresh
    }

    func prepareForAds() async -> Bool {
        await refreshStatusIfNeeded()
        // The SDK decides whether its current or previously obtained consent permits ads.
        return await consentService.prepareForAds()
    }

    func presentPrivacyOptionsForm() async {
        await consentService.presentPrivacyOptionsForm()
    }
}
