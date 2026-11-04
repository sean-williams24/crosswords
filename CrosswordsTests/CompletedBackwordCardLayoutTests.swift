import CoreGraphics
import Testing
@testable import Backword

@Suite("Completed Backword Home card alignment")
struct CompletedBackwordCardLayoutTests {
    @Test("Logo and cells centre above the footer in taller iPad and shared grid cards",
          arguments: [CGFloat(170), 240, 400], [CGFloat(280), 450, 600])
    func tallerCards(height: CGFloat, width: CGFloat) {
        let frames = HomeGameCardLayout.frames(
            width: width, minimumHeight: height,
            heights: [.header: 32, .identity: 56, .accessory: 32, .details: 32],
            spacing: 4, identityPosition: .aboveFooter
        )

        let branding = frames.identity.union(frames.accessory)
        let spaceAbove = branding.minY
        let spaceBelow = frames.details.minY - 4 - branding.maxY
        #expect(spaceAbove > 0)
        #expect(spaceAbove == spaceBelow)
        #expect(branding.midX == width / 2)
        #expect(frames.accessory.minY - frames.identity.maxY == 4)
        #expect(frames.header.minY == 0)
        #expect(frames.details.maxY == height)
        #expect(frames.size.height == height)
    }

    @Test("Compact iPhone cards retain their existing logo, cells and footer positions")
    func compactCard() {
        let frames = HomeGameCardLayout.frames(
            width: 280, minimumHeight: 120,
            heights: [.header: 32, .identity: 56, .accessory: 32, .details: 32],
            spacing: 4, identityPosition: .aboveFooter
        )

        #expect(frames.size.height == 128)
        #expect(frames.identity.minY == 0)
        #expect(frames.accessory.minY == 60)
        #expect(frames.details.minY == 96)
        #expect(frames.header.minY == 0)
    }

    @Test("Larger completed content grows the card without overlapping the footer",
          arguments: [CGFloat(170), 700])
    func enlargedContent(height: CGFloat) {
        let frames = HomeGameCardLayout.frames(
            width: 450, minimumHeight: height,
            heights: [.header: 120, .identity: 200, .accessory: 180, .details: 180],
            spacing: 4, identityPosition: .aboveFooter
        )

        #expect(frames.identity.minY >= 0)
        #expect(frames.accessory.minY == frames.identity.maxY + 4)
        #expect(frames.accessory.maxY + 4 <= frames.details.minY)
        #expect(frames.header.maxY + 4 <= frames.details.minY)
        #expect(frames.identity.minY == frames.details.minY - 4 - frames.accessory.maxY)
        #expect(frames.size.height >= height)
    }
}
