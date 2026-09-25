import CoreGraphics
import Testing
@testable import Backword

@Suite("Anagram tray layout")
struct AnagramTrayLayoutTests {
    @Test func centersBalancedRows() {
        for (tileCount, topCount, bottomCount) in [(7, 4, 3), (8, 4, 4), (9, 5, 4)] {
            let frames = AnagramTrayLayout.tileFrames(count: tileCount, width: 320, spacing: 8)
            #expect(frames.count == tileCount)
            #expect(frames.filter { $0.minY == 0 }.count == topCount)
            #expect(frames.filter { $0.minY > 0 }.count == bottomCount)
            if tileCount < 9 { #expect(frames[0].minX > 0) }

            for row in [Array(frames.prefix(topCount)), Array(frames.suffix(bottomCount))] {
                #expect(abs(row.first!.minX - (320 - row.last!.maxX)) < 0.001)
                #expect(row.allSatisfy { $0.width == $0.height && $0.width > 0 })
            }
        }
    }
}
