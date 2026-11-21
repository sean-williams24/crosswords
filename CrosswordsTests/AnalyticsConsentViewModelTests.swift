import Foundation
import Testing
@testable import Backword

@MainActor
@Suite("Optional iOS analytics")
struct AnalyticsConsentViewModelTests {
    @Test("Missing or unknown choices stay disabled and show the prompt", arguments: ["", "unknown"])
    func defaultIsOff(rawValue: String) {
        let suiteName = "AnalyticsConsentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        if !rawValue.isEmpty { defaults.set(rawValue, forKey: AnalyticsConsent.storageKey) }
        var applied: [Bool] = []
        let model = AnalyticsConsentViewModel(defaults: defaults, applyConsent: { applied.append($0) })
        #expect(model.shouldShowPrompt)
        #expect(!model.isEnabled)
        #expect(applied == [false])
    }

    @Test("Accept and decline are persisted and survive the next launch", arguments: [false, true])
    func persistsChoice(enabled: Bool) {
        let suiteName = "AnalyticsConsentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = AnalyticsConsentViewModel(defaults: defaults, applyConsent: { _ in })
        model.setEnabled(enabled)
        #expect(!model.shouldShowPrompt)
        #expect(model.isEnabled == enabled)
        var restored: [Bool] = []
        let nextLaunch = AnalyticsConsentViewModel(defaults: defaults, applyConsent: { restored.append($0) })
        #expect(!nextLaunch.shouldShowPrompt)
        #expect(nextLaunch.isEnabled == enabled)
        #expect(restored == [enabled])
    }

    @Test("Settings withdrawal and reacceptance update collection immediately")
    func changesInSettings() {
        let suiteName = "AnalyticsConsentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var applied: [Bool] = []
        let model = AnalyticsConsentViewModel(defaults: defaults, applyConsent: { applied.append($0) })
        model.setEnabled(true)
        model.setEnabled(false)
        #expect(model.choice == .declined)
        #expect(!model.shouldShowPrompt)
        #expect(!model.isEnabled)
        model.setEnabled(true)
        #expect(applied == [false, true, false, true])
        #expect(AnalyticsConsent.savedChoice(in: defaults) == .accepted)
    }

}

#if os(iOS)
import SwiftUI
import UIKit

@MainActor
@Suite("Analytics consent banner layout")
struct AnalyticsConsentBannerLayoutTests {
    @Test("The dismissal uses a 0.8-second animation and respects Reduce Motion")
    func dismissalAnimationTiming() {
        #expect(AnalyticsConsentBannerPresentation.dismissalAnimation(reduceMotion: false) == Animation.easeInOut(duration: 0.8))
        #expect(AnalyticsConsentBannerPresentation.dismissalAnimation(reduceMotion: true) == nil)
    }

    @Test("The footer stays mounted through the slide after consent is saved", arguments: [false, true])
    func footerRemainsVisibleDuringDismissal(enabled: Bool) {
        let suiteName = "AnalyticsConsentBannerDismissalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = AnalyticsConsentViewModel(defaults: defaults, applyConsent: { _ in })

        #expect(AnalyticsConsentBannerPresentation.showsFooter(shouldShowPrompt: model.shouldShowPrompt, isDismissing: false))
        model.setEnabled(enabled)

        #expect(AnalyticsConsent.savedChoice(in: defaults) == (enabled ? .accepted : .declined))
        #expect(AnalyticsConsentBannerPresentation.showsFooter(shouldShowPrompt: model.shouldShowPrompt, isDismissing: true))
        #expect(!AnalyticsConsentBannerPresentation.showsFooter(shouldShowPrompt: model.shouldShowPrompt, isDismissing: false))
    }

    @Test("The banner stays compact on narrow phones at every Dynamic Type size",
          arguments: [CGFloat(320), CGFloat(393)], DynamicTypeSize.allCases)
    func compactBanner(width: CGFloat, textSize: DynamicTypeSize) {
        func fittedSize(_ size: DynamicTypeSize) -> CGSize {
            let host = UIHostingController(rootView:
                AnalyticsConsentBanner(selectConsent: { _ in })
                    .environment(\.dynamicTypeSize, size)
            )
            return host.sizeThatFits(in: CGSize(width: width, height: 1_000))
        }

        let size = fittedSize(textSize)
        #expect(size.width <= width + 0.5)
        #expect(size.height > 0)
        #expect(size.height <= 260)
        if textSize > .xxxLarge {
            #expect(abs(size.height - fittedSize(.xxxLarge).height) < 0.5)
        }
    }

    @Test("The footer slides far enough to clear the physical screen edge", arguments: [CGFloat(0), CGFloat(34)])
    func dismissalClearsScreen(bottomSafeArea: CGFloat) {
        let bannerHeight: CGFloat = 160
        let topAtRest = -bannerHeight - bottomSafeArea
        let offset = AnalyticsConsentBannerPresentation.dismissalOffset(
            bannerHeight: bannerHeight,
            bottomSafeArea: bottomSafeArea
        )

        #expect(topAtRest + offset == 0)
    }
}
#endif
