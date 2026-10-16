import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
@testable import Backword

@MainActor
@Suite("Midword gameplay logo")
struct MidwordLogoTests {
    @Test("The stacked logo stays green above readable text in both appearances",
          arguments: [ColorScheme.light, .dark])
    func logoColours(colorScheme: ColorScheme) throws {
        let assetURL = URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Backword/Resources/Assets.xcassets/MidwordLogo.imageset")
        let contents = try #require(JSONSerialization.jsonObject(
            with: Data(contentsOf: assetURL.appendingPathComponent("Contents.json"))
        ) as? [String: Any])
        let images = try #require(contents["images"] as? [[String: String]])
        let filename = try #require(images.first { $0["scale"] == "1x" }?["filename"])
        let source = try #require(CGImageSourceCreateWithURL(assetURL.appendingPathComponent(filename) as CFURL, nil))
        let original = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let renderer = ImageRenderer(content: MidwordLogo(image: Image(decorative: original, scale: 1))
            .environment(\.colorScheme, colorScheme))
        renderer.scale = 2
        let rendered = try #require(renderer.cgImage)
        #expect(rendered.height == 76)

        var pixels = [UInt8](repeating: 0, count: rendered.width * rendered.height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: rendered.width, height: rendered.height,
            bitsPerComponent: 8, bytesPerRow: rendered.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(rendered, in: CGRect(x: 0, y: 0, width: rendered.width, height: rendered.height))

        var greenPixels = 0
        var textPixels = 0
        for y in 0..<rendered.height {
            for x in 0..<rendered.width {
                let offset = (y * rendered.width + x) * 4
                guard pixels[offset + 3] > 250 else { continue }
                let rgb = pixels[offset..<(offset + 3)].map(Double.init)
                if y < Int(Double(rendered.height) * 0.49) {
                    #expect(rgb[1] > rgb[0] * 1.2 && rgb[1] > rgb[2] * 1.2)
                    greenPixels += 1
                } else {
                    if colorScheme == .dark {
                        #expect(rgb.allSatisfy { $0 > 245 })
                    } else {
                        #expect(rgb.allSatisfy { $0 < 10 })
                    }
                    textPixels += 1
                }
            }
        }
        #expect(greenPixels > 50)
        #expect(textPixels > 50)
    }
}
