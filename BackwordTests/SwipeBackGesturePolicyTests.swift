import Testing
import UIKit
@testable import Backword

@Suite("Swipe back gesture policy")
struct SwipeBackGesturePolicyTests {
    @Test("Enabling swipe back clears SwiftUI gesture delegate")
    func enablingSwipeBackClearsGestureDelegate() {
        let navigationController = UINavigationController()
        let delegate = GestureDelegate()
        navigationController.interactivePopGestureRecognizer?.delegate = delegate
        navigationController.interactivePopGestureRecognizer?.isEnabled = false

        SwipeBackGesturePolicy.enable(on: navigationController)

        #expect(navigationController.interactivePopGestureRecognizer?.isEnabled == true)
        #expect(navigationController.interactivePopGestureRecognizer?.delegate == nil)
    }
}

private final class GestureDelegate: NSObject, UIGestureRecognizerDelegate {}
