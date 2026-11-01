#if canImport(UIKit)
import SwiftUI
import UIKit

/// SwiftUI needs a window before placement callbacks and UIKit descendants exist.
@MainActor
func withLaidOutHostingController<Content: View, Result>(
    _ host: UIHostingController<Content>,
    size: CGSize,
    inspect: () throws -> Result
) rethrows -> Result {
    let window = UIWindow(frame: CGRect(origin: .zero, size: size))
    host.safeAreaRegions = []
    window.rootViewController = host
    window.isHidden = false
    defer {
        window.isHidden = true
        window.rootViewController = nil
    }
    host.view.frame = CGRect(origin: .zero, size: size)
    window.setNeedsLayout()
    window.layoutIfNeeded()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    return try inspect()
}
#endif
