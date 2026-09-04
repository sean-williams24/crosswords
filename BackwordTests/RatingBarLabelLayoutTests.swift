import CoreGraphics
import Testing
@testable import Backword

@Suite("Rating bar label layout")
struct RatingBarLabelLayoutTests {
    @Test("Centers label under the dot away from edges")
    func centersLabelUnderDot() {
        let offset = RatingBarLabelLayout.leadingOffset(
            barWidth: 300,
            fraction: 0.5,
            labelWidth: 80
        )

        #expect(offset == 110)
    }

    @Test("Pins label to trailing edge near the end of the bar")
    func pinsLabelToTrailingEdge() {
        let offset = RatingBarLabelLayout.leadingOffset(
            barWidth: 300,
            fraction: 1,
            labelWidth: 120
        )

        #expect(offset == 180)
    }

    @Test("Keeps oversized label trailing-aligned to the bar")
    func oversizedLabelMovesLeft() {
        let offset = RatingBarLabelLayout.leadingOffset(
            barWidth: 300,
            fraction: 1,
            labelWidth: 340
        )

        #expect(offset == -40)
    }
}

@Suite("Rating progress track style")
struct RatingProgressTrackStyleTests {
    @Test("Simple track reserves its compact layout height")
    func simpleTrackHeight() {
        #expect(RatingProgressTrack.Style.simple.height == 4)
        #expect(RatingProgressTrack.Style.simple.cornerRadius == 0)
    }

    @Test("Detailed track reserves room for its marker")
    func detailedTrackHeight() {
        let style = RatingProgressTrack.Style.detailed(
            markerColor: .appAccent,
            pulses: false,
            markerAnimationDelay: 0.05
        )

        #expect(style.height == 18)
        #expect(style.cornerRadius == 20)
    }
}
