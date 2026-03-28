import UIKit
import GoogleMobileAds

/// Manages loading and presenting interstitial and rewarded ads for free-tier users.
///
/// Replace the production ad unit IDs before submitting to the App Store.
@MainActor
final class AdService: ObservableObject {

    // MARK: - Ad Unit IDs

    #if DEBUG
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Google test ID
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"      // Google test ID
    #else
    private let interstitialAdUnitID = "ca-app-pub-7357305065047849/2731847065"
    private let rewardedAdUnitID = "ca-app-pub-7357305065047849/XXXXXXXXXX" // TODO: Replace with real rewarded ad unit ID
    #endif

    // MARK: - State

    private var interstitial: GADRewardedInterstitialAd?
    private var rewarded: GADRewardedAd?
    @Published var isRewardedAdReady = false

    // MARK: - Init

    init() {
        GADMobileAds.sharedInstance().start()
        Task {
            await loadAd()
            await loadRewardedAd()
        }
    }

    // MARK: - Load

    func loadAd() async {
        do {
            interstitial = try await GADRewardedInterstitialAd.load(
                withAdUnitID: interstitialAdUnitID,
                request: GADRequest()
            )
        } catch {
            print("[AdService] Failed to load interstitial: \(error.localizedDescription)")
        }
    }

    func loadRewardedAd() async {
        do {
            rewarded = try await GADRewardedAd.load(
                withAdUnitID: rewardedAdUnitID,
                request: GADRequest()
            )
            isRewardedAdReady = rewarded != nil
        } catch {
            isRewardedAdReady = false
            print("[AdService] Failed to load rewarded ad: \(error.localizedDescription)")
        }
    }

    // MARK: - Show

    /// Presents the interstitial ad from the top-most view controller.
    /// Silently no-ops if no ad is loaded or no suitable view controller is found.
    func showInterstitial() {
        guard let ad = interstitial, let rootVC = topViewController() else { return }
        ad.present(fromRootViewController: rootVC, userDidEarnRewardHandler: {})
        interstitial = nil
        Task { await loadAd() }
    }

    /// Presents a rewarded ad. Calls `onReward` if the user earns the reward.
    func showRewardedAd(onReward: @escaping @MainActor () -> Void) {
        guard let ad = rewarded, let rootVC = topViewController() else { return }
        ad.present(fromRootViewController: rootVC) {
            Task { @MainActor in
                onReward()
            }
        }
        rewarded = nil
        isRewardedAdReady = false
        Task { await loadRewardedAd() }
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
