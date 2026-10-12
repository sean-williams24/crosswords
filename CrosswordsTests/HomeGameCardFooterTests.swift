import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import Backword

@MainActor
@Suite("Home game card footer")
struct HomeGameCardFooterTests {
    @Test("Header content stays at the top centre while streak badges stay at the top-right",
          arguments: [CGFloat(180), 350])
    func streakPosition(width: CGFloat) {
        #if canImport(UIKit)
        let streakView = UIView()
        let titleView = UIView()
        #else
        let streakView = NSView()
        let titleView = NSView()
        #endif
        let header = HomeGameCardHeader(spacing: 8) {
            FooterStatusMarker(view: titleView).frame(width: 36, height: 12)
        } streak: {
            FooterStatusMarker(view: streakView).frame(width: 52, height: 32)
        }
        .frame(width: width)

        #if canImport(UIKit)
        let host = UIHostingController(rootView: header)
        let size = host.sizeThatFits(in: CGSize(width: width, height: 10_000))
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        let frame = streakView.convert(streakView.bounds, to: host.view)
        let titleFrame = titleView.convert(titleView.bounds, to: host.view)
        let topDistance = frame.minY - host.view.bounds.minY
        #else
        let host = NSHostingView(rootView: header)
        host.frame = CGRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let frame = streakView.convert(streakView.bounds, to: host)
        let titleFrame = titleView.convert(titleView.bounds, to: host)
        let topDistance = host.isFlipped
            ? frame.minY - host.bounds.minY
            : host.bounds.maxY - frame.maxY
        #endif

        #expect(abs(frame.maxX - width) < 0.5)
        #expect(abs(titleFrame.midX - width / 2) < 0.5)
        #expect(abs(topDistance) < 0.5)
    }

    @Test("Status stays at the bottom centre with and without stats, including narrow cards",
          arguments: [CGFloat(180), 350], [false, true])
    func statusPosition(width: CGFloat, showsStats: Bool) {
        #if canImport(UIKit)
        let statusView = UIView()
        #else
        let statusView = NSView()
        #endif
        let footer = HomeGameCardFooter(spacing: 8) {
            if showsStats { Color.clear.frame(width: 24, height: 24) }
        } status: {
            FooterStatusMarker(view: statusView)
                .frame(width: 120, height: 28)
        } issue: {
            Text("#123").frame(width: 40, height: 12)
        }
        .frame(width: width)

        #if canImport(UIKit)
        let host = UIHostingController(rootView: footer)
        let size = host.sizeThatFits(in: CGSize(width: width, height: 10_000))
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        let statusFrame = statusView.convert(statusView.bounds, to: host.view)
        let bottomDistance = host.view.bounds.maxY - statusFrame.maxY
        #else
        let host = NSHostingView(rootView: footer)
        let size = host.fittingSize
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        let statusFrame = statusView.convert(statusView.bounds, to: host)
        let bottomDistance = host.isFlipped
            ? host.bounds.maxY - statusFrame.maxY
            : statusFrame.minY - host.bounds.minY
        #endif

        #expect(abs(statusFrame.midX - width / 2) < 0.5)
        #expect(abs(bottomDistance) < 0.5)
        #expect(statusFrame.size == CGSize(width: 120, height: 28))
        #expect(size.height == (width == 180 ? (showsStats ? 60 : 48) : 28))
    }
}

#if canImport(UIKit)
private struct FooterStatusMarker: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
#else
private struct FooterStatusMarker: NSViewRepresentable {
    let view: NSView
    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
