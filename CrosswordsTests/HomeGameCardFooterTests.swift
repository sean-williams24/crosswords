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
    @Test("Pro Only badge adds the compact status capsule padding", arguments: [false, true])
    func proOnlyCapsulePadding(dark: Bool) {
        let scheme: ColorScheme = dark ? .dark : .light
        let badge = ProOnlyBadge().environment(\.colorScheme, scheme)
        let content = HStack(spacing: 6) {
            Text("Pro Only")
                .font(AppFont.clueLabel(10))
                .tracking(0.8)
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .offset(y: 1)
        }
        .environment(\.colorScheme, scheme)

        #if canImport(UIKit)
        let badgeSize = UIHostingController(rootView: badge)
            .sizeThatFits(in: CGSize(width: 280, height: 100))
        let contentSize = UIHostingController(rootView: content)
            .sizeThatFits(in: CGSize(width: 280, height: 100))
        #else
        let badgeSize = NSHostingView(rootView: badge).fittingSize
        let contentSize = NSHostingView(rootView: content).fittingSize
        #endif

        #expect(abs(badgeSize.width - contentSize.width - 20) < 1)
        #expect(abs(badgeSize.height - contentSize.height - 10) < 1)
    }

    @Test("Pro Only text and lock use black in Light Mode and white in Dark Mode", arguments: [false, true])
    func proOnlyForeground(dark: Bool) {
        let foreground = Color.homeCardProOnlyForeground(for: dark ? .dark : .light)
        var components: [CGFloat] = []
        #if canImport(UIKit)
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let color = UIColor(foreground).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            components = [red, green, blue, alpha]
        }
        #else
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        appearance?.performAsCurrentDrawingAppearance {
            if let color = NSColor(foreground).usingColorSpace(.sRGB) {
                components = [color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent]
            }
        }
        #endif
        #expect(components == (dark ? [1, 1, 1, 1] : [0, 0, 0, 1]))
    }

    @Test("Header content stays at the top centre while streak badges stay at the top-right",
          arguments: [CGFloat(180), 350], [false, true])
    func streakPosition(width: CGFloat, showsCenter: Bool) {
        #if canImport(UIKit)
        let streakView = UIView()
        let titleView = UIView()
        #else
        let streakView = NSView()
        let titleView = NSView()
        #endif
        let header = HomeGameCardHeader(spacing: 8) {
            if showsCenter {
                FooterStatusMarker(view: titleView).frame(width: 36, height: 12)
            }
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
        if showsCenter { #expect(abs(titleFrame.midX - width / 2) < 0.5) }
        #expect(abs(topDistance) < 0.5)
    }

    @Test("Home streak buttons hide zero counts and keep positive counts visible", arguments: [0, 3])
    func streakVisibility(streak: Int) {
        let button = StreakButton(streak: streak)
        #if canImport(UIKit)
        let host = UIHostingController(rootView: button)
        let size = host.sizeThatFits(in: CGSize(width: 280, height: 10_000))
        #else
        let host = NSHostingView(rootView: button)
        let size = host.fittingSize
        #endif
        if streak == 0 {
            #expect(size == .zero)
        } else {
            #expect(size.width > 20)
            #expect(size.height > 12)
        }
    }

    @Test("Status stays centred with side information below when narrow, with and without stats",
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
        let expectedBottomDistance: CGFloat = width == 180 ? (showsStats ? 32 : 20) : 0
        #expect(abs(bottomDistance - expectedBottomDistance) < 0.5)
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
