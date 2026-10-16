import CoreGraphics
import Testing
@testable import Backword

@Suite("Anagram tray layout")
struct AnagramTrayLayoutTests {
    @Test(arguments: 7...9) func fitsOneCenteredRow(tileCount: Int) {
        for width: CGFloat in [200, 280, 320, 430, 800] {
            let frames = AnagramTrayLayout.tileFrames(count: tileCount, width: width, spacing: 8)
            #expect(frames.count == tileCount)
            #expect(frames.allSatisfy { $0.minY == 0 })
            #expect(frames.allSatisfy { $0.width == $0.height && $0.width > 0 })
            #expect(frames.allSatisfy { $0.width <= AppLayout.anagramTrayPreferredTileSize })
            #expect(abs(frames.first!.minX - (width - frames.last!.maxX)) < 0.001)
            #expect(frames.first!.minX >= -0.001)
            #expect(frames.last!.maxX <= width + 0.001)
            for (left, right) in zip(frames, frames.dropFirst()) {
                #expect(left.maxX <= right.minX)
            }
        }
    }

    @Test func emptyOrUnavailableWidthDoesNotCreateNegativeFrames() {
        #expect(AnagramTrayLayout.tileFrames(count: 0, width: 320, spacing: 8).isEmpty)
        for width: CGFloat in [0, -10] {
            let frames = AnagramTrayLayout.tileFrames(count: 9, width: width, spacing: 8)
            #expect(frames.allSatisfy { $0 == .zero })
        }
    }
}
