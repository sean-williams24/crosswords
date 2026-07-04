import AppTrackingTransparency
import UIKit
import UserMessagingPlatform

enum AdPrivacyOptionsRequirementStatus: Equatable {
    case unknown
    case required
    case notRequired

    var isRequired: Bool {
        self == .required
    }
}

protocol AdConsentPreparing {
    var privacyOptionsRequirementStatus: AdPrivacyOptionsRequirementStatus { get }
    var isPrivacyOptionsRequired: Bool { get }

    @MainActor
    func prepareForAds() async -> Bool

    @MainActor
    func presentPrivacyOptionsForm() async
}

extension AdConsentPreparing {
    var isPrivacyOptionsRequired: Bool {
        privacyOptionsRequirementStatus.isRequired
    }
}

struct GoogleAdConsentService: AdConsentPreparing {
    var privacyOptionsRequirementStatus: AdPrivacyOptionsRequirementStatus {
        switch ConsentInformation.shared.privacyOptionsRequirementStatus {
        case .required:
            return .required
        case .notRequired:
            return .notRequired
        case .unknown:
            fallthrough
        @unknown default:
            return .unknown
        }
    }

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
    func presentPrivacyOptionsForm() async {
        await withCheckedContinuation { continuation in
            ConsentForm.presentPrivacyOptionsForm(from: topViewController()) { _ in
                continuation.resume()
            }
        }
    }

    @MainActor
    private func requestConsentInfoUpdate() async {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        #if DEBUG
        ConsentInformation.shared.reset()

        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        #endif

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
