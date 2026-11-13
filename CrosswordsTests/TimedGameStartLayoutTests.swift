import SwiftUI
import Testing
import UIKit
@testable import Backword

@MainActor
@Suite("Timed game introduction layout")
struct TimedGameStartLayoutTests {
    @Test("Midword's introduction fits narrow phones and iPads at large text sizes",
          arguments: [CGFloat(320), CGFloat(744)], [DynamicTypeSize.large, .accessibility5])
    func introductionFits(width: CGFloat, textSize: DynamicTypeSize) {
        let host = UIHostingController(rootView:
            MidwordStartView(answerLength: 6, onStart: {})
                .environment(\.dynamicTypeSize, textSize)
        )
        for height in [CGFloat(300), CGFloat(700)] {
            let size = host.sizeThatFits(in: CGSize(width: width, height: height))
            #expect(size.width <= width + 0.5)
            #expect(size.height <= height + 0.5)
        }
    }

    @Test("The header stays at the top while the panel centers below it",
          arguments: [CGFloat(300), CGFloat(700)])
    func headerAndPanelPlacement(height: CGFloat) throws {
        let host = UIHostingController(rootView: GameStartScreen {
            StartScreenLayoutProbe(name: "header").frame(height: 40)
        } content: {
            StartScreenLayoutProbe(name: "panel").frame(height: 180)
        })
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: height)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        func find(_ name: String, in view: UIView) -> UIView? {
            if view.accessibilityIdentifier == name { return view }
            return view.subviews.lazy.compactMap { find(name, in: $0) }.first
        }
        let header = try #require(find("header", in: host.view))
        let panel = try #require(find("panel", in: host.view))
        let headerFrame = header.convert(header.bounds, to: host.view)
        let panelFrame = panel.convert(panel.bounds, to: host.view)
        #expect(abs(headerFrame.minY - AppLayout.screenPadding) < 1)
        let remainingTop = headerFrame.maxY + AppLayout.screenPadding
        #expect(abs(panelFrame.midY - (remainingTop + height) / 2) < 1)
    }

    @Test("Shared start panels wrap their text and retain the Start control on narrow screens")
    func cardWraps() {
        func height(width: CGFloat) -> CGFloat {
            let host = UIHostingController(rootView: TimedGameStartCard(
                heading: "Find the connection.\nComplete both words.",
                explanation: "Find the missing middle word that ends the top word and starts the bottom word. Your clock starts when you press Start and keeps running if you leave the game. Solve in under 30 seconds for five points.",
                detail: "6 letters · unlimited guesses · no time limit",
                foreground: .midwordText, accent: .midwordAccent,
                surface: .midwordText.opacity(0.08), onAccent: .midwordOnAccent,
                onStart: {}
            ))
            let size = host.sizeThatFits(in: CGSize(width: width, height: 10_000))
            #expect(size.width <= width + 0.5)
            return size.height
        }
        #expect(height(width: 280) > height(width: 520))
    }
}

private struct StartScreenLayoutProbe: UIViewRepresentable {
    let name: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.accessibilityIdentifier = name
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
