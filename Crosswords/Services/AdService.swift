import UIKit
import GoogleMobileAds

/// Manages loading and presenting interstitial ads for free-tier users.
///
/// Replace the production ad unit ID before submitting to the App Store.
@MainActor
final class AdService: ObservableObject {

    // MARK: - Ad Unit IDs

    #if DEBUG
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Google test ID
    #else
    private let interstitialAdUnitID = "ca-app-pub-7357305065047849/2731847065"
    #endif

    // MARK: - State

    private var interstitial: GADInterstitialAd?

    // MARK: - Init

    init() {
        GADMobileAds.sharedInstance().start()
        Task { await loadAd() }
    }

    // MARK: - Load

    func loadAd() async {
        do {
            interstitial = try await GADInterstitialAd.load(
                withAdUnitID: interstitialAdUnitID,
                request: GADRequest()
            )
        } catch {
            print("[AdService] Failed to load interstitial: \(error.localizedDescription)")
        }
    }

    // MARK: - Show

    /// Presents the interstitial ad from the top-most view controller.
    /// Silently no-ops if no ad is loaded or no suitable view controller is found.
    func showInterstitial() {
        guard let ad = interstitial, let rootVC = topViewController() else { return }
        ad.present(fromRootViewController: rootVC)
        interstitial = nil
        Task { await loadAd() } // preload the next ad
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
