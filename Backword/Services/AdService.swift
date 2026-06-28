import UIKit
import GoogleMobileAds

struct InterstitialPresentationGate {
    let userDefaults: UserDefaults
    var calendar: Calendar = .current

    func key(for type: AdService.UserDefaultsKey) -> String {
        "AdService.lastShown.\(type.rawValue)"
    }

    func shouldPresent(type: AdService.UserDefaultsKey, now: Date = Date()) -> Bool {
        let key = key(for: type)
        let today = calendar.startOfDay(for: now)
        guard let last = userDefaults.object(forKey: key) as? Date else { return true }
        return !calendar.isDate(last, inSameDayAs: today)
    }

    func markPresented(type: AdService.UserDefaultsKey, now: Date = Date()) {
        userDefaults.set(calendar.startOfDay(for: now), forKey: key(for: type))
    }

    func clearPresented(type: AdService.UserDefaultsKey) {
        userDefaults.removeObject(forKey: key(for: type))
    }
}

@MainActor
final class AdService: NSObject, ObservableObject {
    private let logger = AdLogger()

    // MARK: - Ad Unit IDs

    var interstitialAdUnitID: String {
        #if DEBUG
        // Simulator or local dev build
        return "ca-app-pub-3940256099942544/4411468910"
        #else
        // Check if running in TestFlight sandbox
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "ca-app-pub-3940256099942544/4411468910"
        }
        // Live App Store build
        return "ca-app-pub-7357305065047849/2731847065"
        #endif
    }

    var rewardedAdUnitID: String {
        #if DEBUG
        // Simulator or local dev build
        return "ca-app-pub-3940256099942544/1712485313"
        #else
        // Check if running in TestFlight sandbox
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "ca-app-pub-3940256099942544/1712485313"
        }
        // Live App Store build
        return "ca-app-pub-7357305065047849/9890466910"
        #endif
    }

    // MARK: - State
    enum RewardedAdResult {
        case earnedReward
        case unavailable
        case failedToPresent
        case dismissedWithoutReward
    }

    @Published var rewardedAdDidDismiss = false
    @Published private(set) var adStartupDidComplete = false
    @Published private(set) var isPresentingFullScreenAd = false
    var rewardGranted = false
    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var interstitialContext: InterstitialPresentationContext?
    private var directInterstitialContext: DirectAdPresentationContext?
    private var rewardedAdContext: RewardedAdPresentationContext?
    private let interstitialGate: InterstitialPresentationGate
    private let adConsentService: AdConsentPreparing
    private var startupTask: Task<Bool, Never>?
    private var adsHaveStarted = false

    // MARK: - Init

    init(
        interstitialGate: InterstitialPresentationGate = InterstitialPresentationGate(userDefaults: .standard),
        adConsentService: AdConsentPreparing = GoogleAdConsentService()
    ) {
        self.interstitialGate = interstitialGate
        self.adConsentService = adConsentService
        super.init()
    }

    @discardableResult
    func prepareAdsIfNeeded() async -> Bool {
        if adsHaveStarted {
            return true
        }

        if let startupTask {
            return await awaitStartupTask(startupTask)
        }

        let task = Task { @MainActor [self] in
            adStartupDidComplete = false
            guard await adConsentService.prepareForAds() else {
                startupTask = nil
                adStartupDidComplete = true
                return false
            }

            guard !adsHaveStarted else {
                startupTask = nil
                adStartupDidComplete = true
                return true
            }

            await MobileAds.shared.start()
            adsHaveStarted = true
            startupTask = nil

            await loadAd()
            await loadRewardedAd()
            adStartupDidComplete = true
            return true
        }
        startupTask = task
        return await awaitStartupTask(task)
    }

    private func awaitStartupTask(_ task: Task<Bool, Never>) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await task.value
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                return false
            }

            let result = await group.next() ?? false
            group.cancelAll()

            if !result {
                task.cancel()
                startupTask = nil
                adStartupDidComplete = true
            }

            return result
        }
    }

    // MARK: - Load

    @discardableResult
    func loadAd() async -> Bool {
        do {
            interstitial = try await InterstitialAd.load(
                with: interstitialAdUnitID,
                request: Request()
            )
            interstitial?.fullScreenContentDelegate = self
            logger.interstitialAdLoaded()
            return true
        } catch {
            interstitial = nil
            logger.interstitialAdFailedToLoad(error)
            return false
        }
    }

    func loadRewardedAd() async {
        do {
            rewarded = try await RewardedAd.load(
                with: rewardedAdUnitID,
                request: Request()
            )
            rewarded?.fullScreenContentDelegate = self
            logger.rewardedAdLoaded()
        } catch {
            logger.rewardedAdFailedToLoad(error)
        }
    }

    // MARK: - Debug

    #if DEBUG
    private static let debugAdsEnabledKey = "debug_adsEnabled"
    @Published var debugAdsEnabled: Bool = UserDefaults.standard.object(forKey: debugAdsEnabledKey) as? Bool ?? true

    func setDebugAdsEnabled(_ value: Bool) {
        debugAdsEnabled = value
        UserDefaults.standard.set(value, forKey: Self.debugAdsEnabledKey)
    }
    #endif

    // MARK: - Show

    /// Presents the interstitial ad from the top-most view controller.
    /// Silently no-ops if no ad is loaded or no suitable view controller is found.
    func showInterstitial() {
        #if DEBUG
        guard debugAdsEnabled else {
            logger.interstitialSkippedDebugDisabled()
            return
        }
        #endif
        guard adsHaveStarted else {
            Task { await prepareAdsIfNeeded() }
            logger.interstitialUnavailableForDirectPresentation()
            return
        }
        guard let ad = interstitial else {
            logger.interstitialUnavailableForDirectPresentation()
            Task { await loadAd() }
            return
        }
        guard let presenter = topViewController() else {
            logger.interstitialDirectPresentationPresenterUnavailable()
            Task { await loadAd() }
            return
        }
        let attemptID = UUID().uuidString
        directInterstitialContext = DirectAdPresentationContext(
            attemptID: attemptID,
            requestedAt: Date()
        )
        logger.interstitialDirectPresentationRequested(attemptID: attemptID)
        isPresentingFullScreenAd = true
        ad.present(from: presenter)
    }

    /// Shows the interstitial at most once per calendar day for the given slot identifier.
    /// Subsequent calls on the same day are silently ignored.
    func showInterstitialOnce(for type: UserDefaultsKey, onDismiss: @escaping () -> Void) {
        #if DEBUG
        guard debugAdsEnabled else {
            logger.interstitialSkippedDebugDisabled(for: type)
            onDismiss()
            return
        }
        #endif

        guard adsHaveStarted else {
            Task { await prepareAdsIfNeeded() }
            onDismiss()
            return
        }

        guard interstitialGate.shouldPresent(type: type) else {
            logger.interstitialAlreadyShownToday(for: type)
            onDismiss()
            return
        }

        if presentInterstitialIfReady(for: type, onDismiss: onDismiss) {
            return
        }

        logger.interstitialUnavailableAttemptingForegroundLoad(for: type)
        Task { @MainActor [self] in
            guard interstitialGate.shouldPresent(type: type) else {
                logger.interstitialAlreadyShownAfterForegroundLoadRequest(for: type)
                onDismiss()
                return
            }

            guard await loadAd() else {
                logger.interstitialForegroundLoadFailed(for: type)
                onDismiss()
                return
            }

            guard presentInterstitialIfReady(for: type, onDismiss: onDismiss) else {
                logger.interstitialStillUnavailableAfterForegroundLoad(for: type)
                onDismiss()
                return
            }
        }
    }

    func showRewardedAd(onComplete: @escaping @MainActor (RewardedAdResult) -> Void) {
        guard rewardedAdContext == nil else {
            logger.rewardedAdRequestIgnoredAlreadyInProgress()
            onComplete(.dismissedWithoutReward)
            return
        }

        #if DEBUG
        guard debugAdsEnabled else {
            logger.rewardedAdSkippedDebugDisabled()
            onComplete(.unavailable)
            Task { await loadRewardedAd() }
            return
        }
        #endif

        guard adsHaveStarted else {
            Task { @MainActor [self] in
                guard await prepareAdsIfNeeded() else {
                    onComplete(.unavailable)
                    return
                }
                showRewardedAd(onComplete: onComplete)
            }
            return
        }

        guard let rewarded else {
            Task { await loadRewardedAd() }
            logger.rewardedAdUnavailableGrantingFallback()
            onComplete(.unavailable)
            return
        }

        guard let presenter = topViewController() else {
            self.rewarded = nil
            Task { await loadRewardedAd() }
            logger.rewardedAdPresenterUnavailable()
            onComplete(.failedToPresent)
            return
        }

        let attemptID = UUID().uuidString
        rewardedAdContext = RewardedAdPresentationContext(
            attemptID: attemptID,
            requestedAt: Date(),
            completion: onComplete
        )
        rewardedAdDidDismiss = false
        rewardGranted = false
        logger.rewardedAdPresentationRequested(attemptID: attemptID)
        isPresentingFullScreenAd = true
        Task { @MainActor in
            rewarded.present(from: presenter) { @MainActor [weak self] in
                guard let self else { return }
                logger.rewardedAdRewardEarned(attemptID: rewardedAdContext?.attemptID)
                rewardGranted = true
            }
        }
    }

    func resetUserDefaults() {
        UserDefaultsKey.allCases
            .forEach { UserDefaults.standard.removeObject(forKey: "AdService.lastShown.\($0.rawValue)") }
        Task { await loadAd() }
    }

    enum UserDefaultsKey: String, CaseIterable {
        case backwordOpen = "backword_open"
        case dailyPuzzleOpen = "daily_puzzle_open"
        case wotdDismiss = "wotd_dismiss"
    }

    // MARK: - Helpers

    private func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.keyWindow?.rootViewController
        else { return nil }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private func completeRewardedAd(with result: RewardedAdResult) {
        guard let context = rewardedAdContext else { return }
        rewardedAdContext = nil
        context.stuckAdTask?.cancel()
        logger.rewardedAdCompleted(with: result, attemptID: context.attemptID, presentedAt: context.presentedAt)
        context.completion(result)
    }

    private func completeInterstitial() {
        guard let context = interstitialContext else { return }
        interstitialContext = nil
        context.stuckAdTask?.cancel()
        context.onDismiss()
    }

    private func clearDirectInterstitialContext() {
        directInterstitialContext?.stuckAdTask?.cancel()
        directInterstitialContext = nil
    }

    private func dismissTopAdControllerIfNeeded() {
        guard let top = topViewController() else { return }
        let className = String(describing: type(of: top))
        guard Self.isGoogleFullScreenAdControllerClassName(className) else { return }
        top.dismiss(animated: true)
    }

    nonisolated static func isGoogleFullScreenAdControllerClassName(_ className: String) -> Bool {
        className.contains("GAD") || className.contains("GoogleMobileAds")
    }

    private func presentInterstitialIfReady(for type: UserDefaultsKey, onDismiss: @escaping @MainActor () -> Void) -> Bool {
        guard interstitialContext == nil else {
            logger.interstitialRequestIgnoredAlreadyInProgress(for: type)
            return true
        }

        guard let ad = interstitial else {
            return false
        }

        guard let presenter = topViewController() else {
            logger.interstitialPresenterUnavailable(for: type)
            Task { await loadAd() }
            return false
        }

        interstitialGate.markPresented(type: type)
        let attemptID = UUID().uuidString
        interstitialContext = InterstitialPresentationContext(
            type: type,
            attemptID: attemptID,
            requestedAt: Date(),
            onDismiss: onDismiss
        )
        logger.interstitialPresentationRequested(for: type, attemptID: attemptID)
        isPresentingFullScreenAd = true
        ad.present(from: presenter)
        return true
    }

    private func failInterstitialPresentation() {
        if let context = interstitialContext {
            interstitialGate.clearPresented(type: context.type)
        }
        completeInterstitial()
    }

    private func markInterstitialWillPresent() -> (attemptID: String?, presentedAt: Date?) {
        guard var context = interstitialContext else { return (nil, nil) }
        let presentedAt = Date()
        context.presentedAt = presentedAt
        context.stuckAdTask = makePossibleStuckAdTask(
            format: .interstitial,
            placement: context.type,
            attemptID: context.attemptID,
            presentedAt: presentedAt
        )
        interstitialContext = context
        return (context.attemptID, presentedAt)
    }

    private func markDirectInterstitialWillPresent() -> (attemptID: String?, presentedAt: Date?) {
        guard var context = directInterstitialContext else { return (nil, nil) }
        let presentedAt = Date()
        context.presentedAt = presentedAt
        context.stuckAdTask = makePossibleStuckAdTask(
            format: .interstitial,
            placement: nil,
            attemptID: context.attemptID,
            presentedAt: presentedAt
        )
        directInterstitialContext = context
        return (context.attemptID, presentedAt)
    }

    private func markRewardedWillPresent() -> (attemptID: String?, presentedAt: Date?) {
        guard var context = rewardedAdContext else { return (nil, nil) }
        let presentedAt = Date()
        context.presentedAt = presentedAt
        context.stuckAdTask = makePossibleStuckAdTask(
            format: .rewarded,
            placement: nil,
            attemptID: context.attemptID,
            presentedAt: presentedAt
        )
        rewardedAdContext = context
        return (context.attemptID, presentedAt)
    }

    private func makePossibleStuckAdTask(
        format: BackwordAnalyticsEvent.AdFormat,
        placement: UserDefaultsKey?,
        attemptID: String,
        presentedAt: Date
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard !Task.isCancelled else { return }
            self?.logger.possibleStuckAd(
                format: format,
                placement: placement,
                attemptID: attemptID,
                presentedAt: presentedAt
            )
            self?.recoverPossiblyStuckAd(format: format, attemptID: attemptID)
        }
    }

    private func recoverPossiblyStuckAd(format: BackwordAnalyticsEvent.AdFormat, attemptID: String) {
        switch format {
        case .interstitial:
            let matchesInterstitial = interstitialContext?.attemptID == attemptID
            let matchesDirectInterstitial = directInterstitialContext?.attemptID == attemptID
            guard matchesInterstitial || matchesDirectInterstitial else { return }

            logger.recoveringPossiblyStuckAd(format: format, attemptID: attemptID)
            dismissTopAdControllerIfNeeded()
            interstitial = nil
            isPresentingFullScreenAd = false

            if matchesInterstitial {
                completeInterstitial()
            }
            if matchesDirectInterstitial {
                clearDirectInterstitialContext()
            }

            Task { @MainActor [self] in
                await loadAd()
            }

        case .rewarded:
            guard rewardedAdContext?.attemptID == attemptID else { return }

            logger.recoveringPossiblyStuckAd(format: format, attemptID: attemptID)
            dismissTopAdControllerIfNeeded()
            rewarded = nil
            isPresentingFullScreenAd = false
            rewardGranted = false
            completeRewardedAd(with: .dismissedWithoutReward)

            Task { @MainActor [self] in
                await loadRewardedAd()
            }

        case .unknown:
            return
        }
    }

    private struct InterstitialPresentationContext {
        let type: UserDefaultsKey
        let attemptID: String
        let requestedAt: Date
        var presentedAt: Date?
        var stuckAdTask: Task<Void, Never>?
        let onDismiss: @MainActor () -> Void
    }

    private struct RewardedAdPresentationContext {
        let attemptID: String
        let requestedAt: Date
        var presentedAt: Date?
        var stuckAdTask: Task<Void, Never>?
        let completion: @MainActor (RewardedAdResult) -> Void
    }

    private struct DirectAdPresentationContext {
        let attemptID: String
        let requestedAt: Date
        var presentedAt: Date?
        var stuckAdTask: Task<Void, Never>?
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdService: FullScreenContentDelegate {
    func ad(
      _ ad: FullScreenPresentingAd,
      didFailToPresentFullScreenContentWithError error: Error
    ) {
        if let _ = ad as? RewardedAd {
            logger.rewardedAdFailedToPresent(
                error,
                attemptID: rewardedAdContext?.attemptID,
                presentedAt: rewardedAdContext?.presentedAt
            )
            rewarded = nil
            isPresentingFullScreenAd = false
            rewardGranted = false
            completeRewardedAd(with: .failedToPresent)
            Task { @MainActor [self] in
                await loadRewardedAd()
            }
        } else {
            logger.interstitialAdFailedToPresent(
                error,
                attemptID: interstitialContext?.attemptID ?? directInterstitialContext?.attemptID,
                presentedAt: interstitialContext?.presentedAt ?? directInterstitialContext?.presentedAt
            )
            interstitial = nil
            isPresentingFullScreenAd = false
            failInterstitialPresentation()
            clearDirectInterstitialContext()
            Task { @MainActor [self] in
                await loadAd()
            }
        }
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        if let _ = ad as? InterstitialAd {
            let presentation: (attemptID: String?, presentedAt: Date?)
            if interstitialContext == nil {
                presentation = markDirectInterstitialWillPresent()
            } else {
                presentation = markInterstitialWillPresent()
            }
            logger.fullScreenAdWillPresent(ad, attemptID: presentation.attemptID, presentedAt: presentation.presentedAt ?? Date())
        } else if let _ = ad as? RewardedAd {
            let presentation = markRewardedWillPresent()
            logger.fullScreenAdWillPresent(ad, attemptID: presentation.attemptID, presentedAt: presentation.presentedAt ?? Date())
        } else {
            logger.fullScreenAdWillPresent(ad, attemptID: nil, presentedAt: Date())
        }
    }

    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if let _ = ad as? InterstitialAd {
            logger.fullScreenAdWillDismiss(
                ad,
                attemptID: interstitialContext?.attemptID ?? directInterstitialContext?.attemptID,
                presentedAt: interstitialContext?.presentedAt ?? directInterstitialContext?.presentedAt
            )
        } else if let _ = ad as? RewardedAd {
            logger.fullScreenAdWillDismiss(ad, attemptID: rewardedAdContext?.attemptID, presentedAt: rewardedAdContext?.presentedAt)
        } else {
            logger.fullScreenAdWillDismiss(ad, attemptID: nil, presentedAt: nil)
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if let _ = ad as? InterstitialAd {
            logger.interstitialAdDidDismiss(
                attemptID: interstitialContext?.attemptID ?? directInterstitialContext?.attemptID,
                presentedAt: interstitialContext?.presentedAt ?? directInterstitialContext?.presentedAt
            )
            interstitial = nil
            isPresentingFullScreenAd = false
            completeInterstitial()
            clearDirectInterstitialContext()
            Task { @MainActor [self] in
                await loadAd()
            }
        } else if let _ = ad as? RewardedAd {
            logger.rewardedAdDidDismiss(
                attemptID: rewardedAdContext?.attemptID,
                presentedAt: rewardedAdContext?.presentedAt
            )
            rewarded = nil
            isPresentingFullScreenAd = false
            if rewardGranted {
                completeRewardedAd(with: .earnedReward)
            } else {
                completeRewardedAd(with: .dismissedWithoutReward)
            }
            rewardGranted = false
            rewardedAdDidDismiss = true
            Task { @MainActor [self] in
                await loadRewardedAd()
            }
        }
    }
}
