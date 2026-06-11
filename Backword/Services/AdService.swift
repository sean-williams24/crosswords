import UIKit
import GoogleMobileAds

@MainActor
final class AdService: NSObject, ObservableObject {

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
    @Published var rewardedAdDidDismiss = false
    var rewardGranted = false
    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var onAdDismissedCallback: (@MainActor () -> Void)?

    // MARK: - Init

    override init() {
        super.init()
        MobileAds.shared.start()
        Task {
            await loadAd()
            await loadRewardedAd()
        }
    }

    // MARK: - Load

    func loadAd() async {
        do {
            interstitial = try await InterstitialAd.load(
                with: interstitialAdUnitID,
                request: Request()
            )
            interstitial?.fullScreenContentDelegate = self
        } catch {
            print("[AdService] Failed to load interstitial: \(error.localizedDescription)")
        }
    }

    func loadRewardedAd() async {
      do {
        rewarded = try await RewardedAd.load(
          with: rewardedAdUnitID, request: Request())
        rewarded?.fullScreenContentDelegate = self
      } catch {
        print("Failed to load rewarded ad with error: \(error.localizedDescription)")
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
        guard debugAdsEnabled else { return }
        #endif
        guard let ad = interstitial, let rootVC = topViewController() else { return }
        ad.present(from: rootVC)
        interstitial = nil
        Task { await loadAd() }
    }

    /// Shows the interstitial at most once per calendar day for the given slot identifier.
    /// Subsequent calls on the same day are silently ignored.
    func showInterstitialOnce(for type: UserDefaultsKey, onDismiss: @escaping () -> Void) {
        onAdDismissedCallback = onDismiss
        let key = "AdService.lastShown.\(type.rawValue)"
        let today = Calendar.current.startOfDay(for: Date())
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Calendar.current.isDate(last, inSameDayAs: today) {
            onDismiss()
            return
        }
        UserDefaults.standard.set(today, forKey: key)
        showInterstitial()
    }

    func showRewardedAd() {
        guard let rewarded else {
            Task { await loadRewardedAd() }
            return print("Ad wasn't ready.")
        }

        rewardedAdDidDismiss = false
        Task { @MainActor in
            rewarded.present(from: topViewController()) { @MainActor [weak self] in
                self?.rewardGranted = true
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
}

// MARK: - GADFullScreenContentDelegate

extension AdService: FullScreenContentDelegate {
     func ad(
      _ ad: FullScreenPresentingAd,
      didFailToPresentFullScreenContentWithError error: Error
    ) {
        onAdDismissedCallback?()
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if let _ = ad as? InterstitialAd {
            onAdDismissedCallback?()
        } else if let _ = ad as? RewardedAd {
            rewarded = nil
            rewardGranted = false
            rewardedAdDidDismiss = true
            Task { @MainActor [self] in
                await loadRewardedAd()
            }
        }
    }
}
