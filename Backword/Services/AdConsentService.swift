import AppTrackingTransparency
import UIKit
import UserMessagingPlatform

protocol AdConsentPreparing {
    @MainActor
    func prepareForAds() async -> Bool
}

struct GoogleAdConsentService: AdConsentPreparing {
    @MainActor
    func prepareForAds() async -> Bool {
        await requestConsentInfoUpdate()
        await presentConsentFormIfRequired()

        guard ConsentInformation.shared.canRequestAds else {
            return false
        }

        await requestTrackingAuthorizationIfPossible()
        return true
    }

    @MainActor
    private func requestConsentInfoUpdate() async {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                continuation.resume()
            }
        }
    }

    @MainActor
    private func presentConsentFormIfRequired() async {
        await withCheckedContinuation { continuation in
            ConsentForm.loadAndPresentIfRequired(from: topViewController()) { _ in
                continuation.resume()
            }
        }
    }

    @MainActor
    private func requestTrackingAuthorizationIfPossible() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            return
        }

        guard UIApplication.shared.applicationState == .active else {
            return
        }

        await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { _ in
                continuation.resume()
            }
        }
    }

    @MainActor
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
