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

    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    private var pendingRewardCallback: (@MainActor () -> Void)?
    @Published var isRewardedAdReady = false

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
    func showInterstitialOnce(for type: UserDefaultsKey) {
        let key = "AdService.lastShown.\(type.rawValue)"
        let today = Calendar.current.startOfDay(for: Date())
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Calendar.current.isDate(last, inSameDayAs: today) {
            return
        }
        UserDefaults.standard.set(today, forKey: key)
        showInterstitial()
    }

    func showRewardedAd(completion: @escaping @MainActor () -> Void) {
        guard let rewarded else {
            return print("Ad wasn't ready.")
        }

        rewarded.present(from: nil) {
            completion()
        }
    }

    func resetUserDefaults() {
        UserDefaultsKey.allCases
            .forEach { UserDefaults.standard.removeObject(forKey: "AdService.lastShown.\($0.rawValue)") }
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
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }

    func ad(
      _ ad: FullScreenPresentingAd,
      didFailToPresentFullScreenContentWithError error: Error
    ) {
      print("\(#function) called")
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("\(#function) called")
        // Clear the rewarded ad.
        rewarded = nil

        Task { @MainActor [self] in
            await loadRewardedAd()
        }
    }
}
