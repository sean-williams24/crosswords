import UIKit
import GoogleMobileAds

/// Manages loading and presenting interstitial and rewarded ads for free-tier users.
///
/// Replace the production ad unit IDs before submitting to the App Store.
@MainActor
final class AdService: NSObject, ObservableObject {

    // MARK: - Ad Unit IDs

    #if DEBUG
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Google test ID
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"      // Google test ID
    #else
    private let interstitialAdUnitID = "ca-app-pub-7357305065047849/2731847065"
    private let rewardedAdUnitID = "ca-app-pub-7357305065047849/XXXXXXXXXX" // TODO: Replace with real rewarded ad unit ID
    #endif

    // MARK: - State

    private var interstitial: RewardedInterstitialAd?
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
            interstitial = try await RewardedInterstitialAd.load(
                with: interstitialAdUnitID,
                request: Request()
            )
        } catch {
            print("[AdService] Failed to load interstitial: \(error.localizedDescription)")
        }
    }

//    func loadRewardedAd() async {
//        do {
//            rewarded = try await GADRewardedAd.load(
//                withAdUnitID: rewardedAdUnitID,
//                request: GADRequest()
//            )
//            isRewardedAdReady = rewarded != nil
//        } catch {
//            isRewardedAdReady = false
//            print("[AdService] Failed to load rewarded ad: \(error.localizedDescription)")
//        }
//    }

//    @Published var coins = 0
//    private var rewardedAd: RewardedAd?

    func loadRewardedAd() async {
      do {
        rewarded = try await RewardedAd.load(
          with: rewardedAdUnitID, request: Request())
        rewarded?.fullScreenContentDelegate = self
      } catch {
        print("Failed to load rewarded ad with error: \(error.localizedDescription)")
      }
    }

    // MARK: - Show

    /// Presents the interstitial ad from the top-most view controller.
    /// Silently no-ops if no ad is loaded or no suitable view controller is found.
    func showInterstitial() {
        guard let ad = interstitial, let rootVC = topViewController() else { return }
        ad.present(from: rootVC, userDidEarnRewardHandler: {})
        interstitial = nil
        Task { await loadAd() }
    }

    /// Presents a rewarded ad. Calls `onReward` when the ad is dismissed (regardless of
    /// whether the user watched it fully or tapped the close button).
//    func showRewardedAd(onReward: @escaping @MainActor () -> Void) {
//        guard let ad = rewarded, let rootVC = topViewController() else { return }
//        pendingRewardCallback = onReward
//        ad.fullScreenContentDelegate = self
//        ad.present(from: rootVC, userDidEarnRewardHandler: {})
//        rewarded = nil
////        isRewardedAdReady = false
//        Task { await loadRewardedAd() }
//    }

    func showRewardedAd(completion: @escaping @MainActor () -> Void) {
      guard let rewarded else {
        return print("Ad wasn't ready.")
      }

        rewarded.present(from: nil) {
        let reward = rewarded.adReward
        print("Reward amount: \(reward.amount)")
//        self.addCoins(reward.amount.intValue)
          completion()
      }
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
//    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
//        Task { @MainActor [self] in
//            pendingRewardCallback?()
//            pendingRewardCallback = nil
//        }
//    }

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
