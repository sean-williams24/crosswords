import CoreGraphics
import Testing
@testable import Backword

@Suite("Zoomable view scale policy")
struct ZoomableViewScalePolicyTests {
    @Test("Uses measured content size when available")
    func usesMeasuredContentSizeWhenAvailable() {
        let size = ZoomableViewScalePolicy.preferredContentSize(
            measuredSize: CGSize(width: 900, height: 900),
            fallbackSize: CGSize(width: 900, height: 1400)
        )

        #expect(size == CGSize(width: 900, height: 900))
    }

    @Test("Falls back to view bounds when measured content size is invalid")
    func fallsBackWhenMeasuredContentSizeIsInvalid() {
        let size = ZoomableViewScalePolicy.preferredContentSize(
            measuredSize: CGSize(width: 0, height: 0),
            fallbackSize: CGSize(width: 900, height: 1400)
        )

        #expect(size == CGSize(width: 900, height: 1400))
    }

    @Test("Allows zooming below one when content is taller than viewport")
    func allowsZoomingBelowOneWhenContentIsTooTall() {
        let scale = ZoomableViewScalePolicy.fitZoomScale(
            viewportSize: CGSize(width: 1200, height: 700),
            contentSize: CGSize(width: 1200, height: 1500),
            configuredMinZoom: 1,
            maxZoom: 2.5
        )

        #expect(abs(scale - (CGFloat(700) / CGFloat(1_500))) < 0.000_001)
    }

    @Test("Keeps configured minimum when content already fits")
    func keepsConfiguredMinimumWhenContentFits() {
        let scale = ZoomableViewScalePolicy.fitZoomScale(
            viewportSize: CGSize(width: 900, height: 900),
            contentSize: CGSize(width: 700, height: 700),
            configuredMinZoom: 1,
            maxZoom: 2.5
        )

        #expect(scale == 1)
    }

    @Test("Recalculates smaller fit after rotation")
    func recalculatesSmallerFitAfterRotation() {
        let landscapeScale = ZoomableViewScalePolicy.fitZoomScale(
            viewportSize: CGSize(width: 1366, height: 650),
            contentSize: CGSize(width: 1366, height: 1366),
            configuredMinZoom: 1,
            maxZoom: 2.5
        )
        let portraitScale = ZoomableViewScalePolicy.fitZoomScale(
            viewportSize: CGSize(width: 900, height: 720),
            contentSize: CGSize(width: 900, height: 900),
            configuredMinZoom: 1,
            maxZoom: 2.5
        )

        #expect(abs(landscapeScale - (CGFloat(650) / CGFloat(1_366))) < 0.000_001)
        #expect(abs(portraitScale - (CGFloat(720) / CGFloat(900))) < 0.000_001)
    }

    @Test("Resets to fit when viewport changes")
    func resetsToFitWhenViewportChanges() {
        let shouldReset = ZoomableViewScalePolicy.shouldResetToFit(
            force: false,
            viewportSize: CGSize(width: 900, height: 1200),
            previousViewportSize: CGSize(width: 1200, height: 700),
            contentSize: CGSize(width: 900, height: 900),
            previousContentSize: CGSize(width: 900, height: 900),
            currentZoomScale: 0.5,
            fitZoomScale: 1
        )

        #expect(shouldReset)
    }

    @Test("Forced reset ignores unchanged sizes")
    func forcedResetIgnoresUnchangedSizes() {
        let shouldReset = ZoomableViewScalePolicy.shouldResetToFit(
            force: true,
            viewportSize: CGSize(width: 900, height: 1200),
            previousViewportSize: CGSize(width: 900, height: 1200),
            contentSize: CGSize(width: 900, height: 900),
            previousContentSize: CGSize(width: 900, height: 900),
            currentZoomScale: 1,
            fitZoomScale: 1
        )

        #expect(shouldReset)
    }
}
