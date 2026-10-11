import Testing
@testable import Backword

@MainActor
@Suite("Deferred ad consent")
struct DeferredAdConsentTests {
    @Test("Launch refresh is silent and retains the required privacy entry point")
    func launchRefreshIsSilent() async {
        let consentService = DeferredConsentStub()
        let coordinator = AdConsentCoordinator(consentService: consentService)

        #expect(await coordinator.refreshStatusIfNeeded())
        #expect(await coordinator.refreshStatusIfNeeded())

        #expect(consentService.events == ["refresh"])
        #expect(coordinator.isPrivacyOptionsRequired)
    }

    @Test("First ad request refreshes status before presenting required prompts")
    func firstAdRequestPreparesConsent() async {
        let consentService = DeferredConsentStub()
        let coordinator = AdConsentCoordinator(consentService: consentService)

        #expect(await coordinator.prepareForAds())

        #expect(consentService.events == ["refresh", "prepare"])
    }

    @Test("A hint after launch uses the completed silent refresh")
    func hintAfterLaunchUsesRefreshedStatus() async {
        let consentService = DeferredConsentStub()
        let coordinator = AdConsentCoordinator(consentService: consentService)

        await coordinator.refreshStatusIfNeeded()
        #expect(consentService.events == ["refresh"])
        #expect(await coordinator.prepareForAds())

        #expect(consentService.events == ["refresh", "prepare"])
    }

    @Test("Hint waits for an in-flight launch refresh even if the launch caller cancels", arguments: [false, true])
    func hintWaitsForLaunchRefresh(cancelLaunch: Bool) async {
        let consentService = DeferredConsentStub(pausesRefresh: true)
        let coordinator = AdConsentCoordinator(consentService: consentService)
        let launchTask = Task { await coordinator.refreshStatusIfNeeded() }
        await consentService.waitForRefreshToStart()
        if cancelLaunch { launchTask.cancel() }

        let hintTask = Task { await coordinator.prepareForAds() }
        await Task.yield()
        #expect(consentService.events == ["refresh"])

        consentService.finishRefresh()
        #expect(await launchTask.value)
        #expect(await hintTask.value)
        #expect(consentService.events == ["refresh", "prepare"])
    }

    @Test("Offline launch stays silent and retries status at the first hint")
    func offlineLaunchRetriesAtHint() async {
        let consentService = DeferredConsentStub(refreshResults: [false, true])
        let coordinator = AdConsentCoordinator(consentService: consentService)

        #expect(!(await coordinator.refreshStatusIfNeeded()))
        #expect(consentService.events == ["refresh"])
        #expect(await coordinator.prepareForAds())

        #expect(consentService.events == ["refresh", "refresh", "prepare"])
    }

    @Test("SDK ad eligibility is respected after a failed status refresh", arguments: [false, true])
    func sdkEligibilityIsRespected(canRequestAds: Bool) async {
        let consentService = DeferredConsentStub(refreshResults: [false], canRequestAds: canRequestAds)
        let coordinator = AdConsentCoordinator(consentService: consentService)

        #expect(await coordinator.prepareForAds() == canRequestAds)
        #expect(consentService.events == ["refresh", "prepare"])
    }

    @Test("Explicit privacy choices remain available before requesting hints")
    func explicitPrivacyChoicesRemainAvailable() async {
        let consentService = DeferredConsentStub()
        let coordinator = AdConsentCoordinator(consentService: consentService)

        await coordinator.refreshStatusIfNeeded()
        await coordinator.presentPrivacyOptionsForm()

        #expect(consentService.events == ["refresh", "privacy-options"])
    }
}

@MainActor
private final class DeferredConsentStub: AdConsentPreparing {
    let privacyOptionsRequirementStatus: AdPrivacyOptionsRequirementStatus = .required
    private let refreshResults: [Bool]
    private let canRequestAds: Bool
    private let pausesRefresh: Bool
    private var refreshCount = 0
    private var refreshStartedContinuation: CheckedContinuation<Void, Never>?
    private var refreshContinuations: [CheckedContinuation<Void, Never>] = []
    private(set) var events: [String] = []

    init(refreshResults: [Bool] = [true], canRequestAds: Bool = true, pausesRefresh: Bool = false) {
        self.refreshResults = refreshResults
        self.canRequestAds = canRequestAds
        self.pausesRefresh = pausesRefresh
    }

    func updateConsentInfo() async -> Bool {
        let result = refreshResults[min(refreshCount, refreshResults.count - 1)]
        refreshCount += 1
        events.append("refresh")
        refreshStartedContinuation?.resume()
        refreshStartedContinuation = nil
        if pausesRefresh {
            await withCheckedContinuation { refreshContinuations.append($0) }
        }
        return result
    }

    func prepareForAds() async -> Bool {
        events.append("prepare")
        return canRequestAds
    }

    func presentPrivacyOptionsForm() async {
        events.append("privacy-options")
    }

    func waitForRefreshToStart() async {
        guard refreshCount == 0 else { return }
        await withCheckedContinuation { refreshStartedContinuation = $0 }
    }

    func finishRefresh() {
        let continuations = refreshContinuations
        refreshContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}
