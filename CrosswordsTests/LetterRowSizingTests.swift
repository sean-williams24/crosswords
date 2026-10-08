import CoreGraphics
import Testing
@testable import Backword

@Suite("Fitted letter rows")
struct LetterRowSizingTests {
    @Test("All supported word lengths fit narrow screens and larger cell sizes", arguments: 3...6)
    func supportedLengthsFit(count: Int) {
        for width: CGFloat in [200, 280, 320, 350, 600] {
            for preferredSize: CGFloat in [44, 56, 80, 280] {
                for spacing: CGFloat in [6, 7, 8] {
                    let sizing = LetterRowSizing(
                        count: count, availableWidth: width,
                        preferredCellSize: preferredSize, spacing: spacing
                    )
                    let rowWidth = CGFloat(count) * sizing.cellSize + CGFloat(count - 1) * sizing.spacing

                    #expect(rowWidth <= width + 0.001)
                    #expect(sizing.cellSize > 0)
                    #expect(sizing.cellSize <= preferredSize)
                    #expect(abs(sizing.cellSize / preferredSize - sizing.spacing / spacing) < 0.001)
                }
            }
        }
    }

    @Test("Short rows keep their preferred cell size on wider screens")
    func preferredSizeWhenSpaceAllows() {
        let sizing = LetterRowSizing(count: 3, availableWidth: 350, preferredCellSize: 56, spacing: 7)
        #expect(sizing.cellSize == 56)
        #expect(sizing.spacing == 7)
    }

    @Test("Six-letter input fills the available width instead of overflowing")
    func sixLetterInputFits() {
        let sizing = LetterRowSizing(count: 6, availableWidth: 280, preferredCellSize: 56, spacing: 7)
        #expect(sizing.cellSize < 56)
        #expect(abs(6 * sizing.cellSize + 5 * sizing.spacing - 280) < 0.001)
    }

    @Test("Completion celebration stays within the row width", arguments: 3...6)
    func celebrationFits(count: Int) {
        let scale = AppLayout.midwordCompletionCelebrationScale
        let sizing = LetterRowSizing(
            count: count, availableWidth: 240,
            preferredCellSize: 80, spacing: AppLayout.midwordCompletionCellSpacing,
            maximumScale: scale
        )
        let rowWidth = CGFloat(count) * sizing.cellSize + CGFloat(count - 1) * sizing.spacing
        #expect(rowWidth * scale <= 240.001)
    }

    @Test("Empty rows and unavailable width produce nonnegative sizes")
    func emptyOrUnavailableWidth() {
        for (count, width) in [(0, 280), (6, 0), (6, -10)] {
            let sizing = LetterRowSizing(
                count: count, availableWidth: CGFloat(width), preferredCellSize: 56, spacing: 7
            )
            #expect(sizing.cellSize == 0)
            #expect(sizing.spacing == 0)
        }
    }
}
