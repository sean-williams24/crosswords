import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif
@testable import Backword

@MainActor
@Suite("Home dashboard viewport adaptation")
struct HomeDashboardViewTests {
    #if canImport(UIKit)
    @Test("A completion trigger brings the daily markers back into view")
    func completionScrollsToTop() async throws {
        let request = ScrollRequest()
        let host = UIHostingController(rootView: ScrollableDashboard(request: request))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        host.safeAreaRegions = []
        window.rootViewController = host
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        host.view.frame = window.bounds
        window.layoutIfNeeded()
        host.view.layoutIfNeeded()
        let scroll = try #require(scrollView(in: host.view))
        scroll.setContentOffset(CGPoint(x: 0, y: 400), animated: false)
        #expect(scroll.contentOffset.y > 0)
        request.value += 1
        try await Task.sleep(for: .milliseconds(50))
        host.view.layoutIfNeeded()
        #expect(abs(scroll.contentOffset.y + scroll.adjustedContentInset.top) < 0.5)
    }

    @MainActor
    private final class ScrollRequest: ObservableObject {
        @Published var value = 0
    }

    private struct ScrollableDashboard: View {
        @ObservedObject var request: ScrollRequest
        var body: some View {
            HomeDashboardView(usesTwoColumns: false, scrollToTopTrigger: request.value) {
                Color.clear
            } compact: {
                Color.clear.frame(height: 1_800)
            }
        }
    }

    private func scrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
    }
    #endif

    @Test("A tall iPad viewport shows the full dashboard")
    func tallViewport() {
        #expect(selectedPresentation(width: 944, height: 1_180, expandedHeight: 1_100) == .expanded)
    }

    @Test("A short regular-width window falls back to compact content")
    func shortViewport() {
        #expect(selectedPresentation(width: 752, height: 900, expandedHeight: 1_100) == .compact)
    }

    @Test("Compact widths keep the phone layout even with enough height")
    func compactWidth() {
        #expect(selectedPresentation(width: 390, height: 1_500, expandedHeight: 1_100,
                                     usesTwoColumns: false) == .compact)
    }

    @Test("Content growth can trigger the compact layout without a viewport change")
    func growingContent() {
        #expect(selectedPresentation(width: 944, height: 1_180, expandedHeight: 1_100) == .expanded)
        #expect(selectedPresentation(width: 944, height: 1_180, expandedHeight: 1_300) == .compact)
    }

    @Test("The expanded dashboard must fit all the way to its bottom padding")
    func exactFitBoundary() {
        #expect(selectedPresentation(width: 944, height: 1_100, expandedHeight: 1_100) == .expanded)
        #expect(selectedPresentation(width: 944, height: 1_099, expandedHeight: 1_100) == .compact)
    }

    @Test("A short two-column dashboard keeps the Archive grid slot")
    func archiveWithCompactWordOfTheDay() {
        let selection = selectedLayout(width: 752, height: 900, expandedHeight: 1_100)
        #expect(selection.value == .compact)
        #expect(selection.showsArchiveCard == true)
    }

    @Test("Stacking the game cards removes the Archive grid slot")
    func archiveRemovedFromStackedGames() {
        let selection = selectedLayout(width: 390, height: 900, expandedHeight: 1_100,
                                       usesTwoColumns: false)
        #expect(selection.value == .compact)
        #expect(selection.showsArchiveCard == false)
    }

    private func selectedPresentation(
        width: CGFloat, height: CGFloat, expandedHeight: CGFloat, usesTwoColumns: Bool = true
    ) -> Presentation? {
        selectedLayout(width: width, height: height, expandedHeight: expandedHeight,
                       usesTwoColumns: usesTwoColumns).value
    }

    private func selectedLayout(
        width: CGFloat, height: CGFloat, expandedHeight: CGFloat, usesTwoColumns: Bool = true
    ) -> Selection {
        let selection = Selection()
        let content = dashboard(selection: selection, expandedHeight: expandedHeight,
                                usesTwoColumns: usesTwoColumns)
            .environment(\.horizontalSizeClass, usesTwoColumns ? .regular : .compact)
        #if canImport(UIKit)
        let host = UIHostingController(rootView: content)
        return withLaidOutHostingController(host, size: CGSize(width: width, height: height)) {
            selection
        }
        #else
        let host = NSHostingView(rootView: content)
        host.frame = CGRect(x: 0, y: 0, width: width, height: height)
        host.layoutSubtreeIfNeeded()
        return selection
        #endif
    }

    private func dashboard(selection: Selection, expandedHeight: CGFloat, usesTwoColumns: Bool = true) -> some View {
        HomeDashboardView(usesTwoColumns: usesTwoColumns) {
            PlacementProbe(selection: selection, presentation: .expanded, height: expandedHeight,
                           showsArchiveCard: true) {
                Color.clear
            }
        } compact: {
            HomeGamesView {
                PlacementProbe(selection: selection, presentation: .compact, height: 1_500,
                               showsArchiveCard: true) {
                    Color.clear
                }
            } stacked: {
                PlacementProbe(selection: selection, presentation: .compact, height: 1_500,
                               showsArchiveCard: false) {
                    Color.clear
                }
            }
        }
    }

    private enum Presentation { case expanded, compact }
    private final class Selection {
        var value: Presentation?
        var showsArchiveCard: Bool?
    }

    /// Records placement, not measurement: ViewThatFits may measure both candidates.
    private struct PlacementProbe: Layout {
        let selection: Selection
        let presentation: Presentation
        let height: CGFloat
        let showsArchiveCard: Bool

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            CGSize(width: proposal.width ?? 0, height: height)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            selection.value = presentation
            selection.showsArchiveCard = showsArchiveCard
            for subview in subviews {
                subview.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
            }
        }
    }
}
