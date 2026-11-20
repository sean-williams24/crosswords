import CoreGraphics
import Testing
@testable import Backword

@Suite("Rating bar label layout")
struct RatingBarLabelLayoutTests {
    @Test("Moves the label along the bar while keeping it inside both edges")
    func followsProgress() {
        let offsets = [0, 0.25, 0.5, 0.75, 1].map { fraction in
            RatingBarLabelLayout.leadingOffset(barWidth: 240, fraction: fraction, labelWidth: 80)
        }

        #expect(offsets == [0, 20, 80, 140, 160])
    }

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
