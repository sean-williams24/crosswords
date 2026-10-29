import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Render the iPhone compositions directly from original captures.
// Run: swift render-iphone.swift /absolute/path/to/2026-10-19 [artwork-key ...]
let assetRoot = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : URL(fileURLWithPath: #filePath).deletingLastPathComponent().path)
let repository = assetRoot.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let fontURL = repository.appendingPathComponent("Backword/Resources/OutfitFonts/Outfit-Bold.ttf")
let width = 1206
let height = 2622
let deviceTop: CGFloat = 442
let capitalHeight: CGFloat = 52
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

struct Artwork {
    let key: String
    let source: String
    let sourceWidth: Int
    let sourceHeight: Int
    let captions: [String]
    let export: String
}

let artworks = [
    Artwork(key: "home", source: "home-new.png", sourceWidth: 1206, sourceHeight: 2622,
            captions: ["Four free", "daily games"], export: "01-home-1206x2622.png"),
    Artwork(key: "backword", source: "backword.png", sourceWidth: 1170, sourceHeight: 2532,
            captions: ["Guess forwards.", "Reveal backwards."], export: "02-backword-1206x2622.png"),
    Artwork(key: "crossword", source: "crossword.png", sourceWidth: 1170, sourceHeight: 2532,
            captions: ["Your daily", "crossword fix"], export: "03-quick-crossword-1206x2622.png"),
    Artwork(key: "midword", source: "midword.png", sourceWidth: 1170, sourceHeight: 2532,
            captions: ["Find the missing link"], export: "04-midword-1206x2622.png"),
    Artwork(key: "anagram", source: "anagram.png", sourceWidth: 1206, sourceHeight: 2622,
            captions: ["Unscramble the Anagram"], export: "06-anagram-1206x2622.png")
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [
        CGFloat((hex >> 16) & 255) / 255,
        CGFloat((hex >> 8) & 255) / 255,
        CGFloat(hex & 255) / 255,
        alpha
    ])!
}

func topRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(x: x, y: CGFloat(height) - y - h, width: w, height: h)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { fatalError("Cannot create \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot save \(url.path)") }
}

guard let provider = CGDataProvider(url: fontURL as CFURL),
      let fontFace = CGFont(provider) else { fatalError("Cannot load Outfit Bold") }
let unitFont = CTFontCreateWithGraphicsFont(fontFace, 100, nil, nil)
let font = CTFontCreateWithGraphicsFont(fontFace, 100 * capitalHeight / CTFontGetCapHeight(unitFont), nil, nil)

func render(_ artwork: Artwork) {
    let sourceURL = assetRoot.appendingPathComponent("sources/\(artwork.source)")
    guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
          let screenshot = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
          ) else { fatalError("Cannot load \(sourceURL.path) or create the rendering context") }
    precondition(screenshot.width == artwork.sourceWidth && screenshot.height == artwork.sourceHeight,
                 "Use the original full-resolution \(artwork.key) capture")
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // Match the native iPad/Archive artwork's approved dark blue-to-navy palette.
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [0x196197, 0x165786, 0x0F4973, 0x083A5B, 0x012B45, 0x011B2D]
            .map { color(UInt32($0)) } as CFArray,
        locations: [0, 0.10, 0.25, 0.50, 0.75, 1]
    )!
    context.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: height), end: .zero,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    let device = topRect(100, deviceTop, 1006, 2096)
    let screen = topRect(144, 488, 918, 918 * CGFloat(screenshot.height) / CGFloat(screenshot.width))
    let framePath = rounded(device, 96)
    precondition(screen.width <= CGFloat(screenshot.width), "Never enlarge the screen capture")
    precondition(device.contains(screen), "The full screen must fit inside the device")

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -16), blur: 28, color: color(0, alpha: 0.48))
    context.addPath(framePath)
    context.setFillColor(color(0x08090A))
    context.fillPath()
    context.restoreGState()

    context.addPath(framePath)
    context.setStrokeColor(color(0x46494C, alpha: 0.72))
    context.setLineWidth(2)
    context.strokePath()
    context.addPath(rounded(device.insetBy(dx: 4, dy: 4), 92))
    context.setStrokeColor(color(0x151719))
    context.setLineWidth(4)
    context.strokePath()

    // One proportional downsample from the original. No generated or resized intermediates.
    context.saveGState()
    context.addPath(rounded(screen, 68))
    context.clip()
    context.draw(screenshot, in: screen)
    context.restoreGState()

    let lines = artwork.captions.map { caption -> CTLine in
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(0xFFFFFF)
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: caption, attributes: attributes))
    }
    let baselineOffsets = lines.indices.map { -76 * CGFloat($0) }
    let bounds = lines.map { CTLineGetImageBounds($0, context) }
    let blockBounds = bounds.enumerated().reduce(CGRect.null) { partial, item in
        partial.union(item.element.offsetBy(dx: 0, dy: baselineOffsets[item.offset]))
    }
    let baselineOrigin = CGFloat(height) - deviceTop / 2 - blockBounds.midY
    context.textMatrix = .identity
    for index in lines.indices {
        precondition(bounds[index].width < CGFloat(width) - 160, "Caption needs horizontal margins")
        context.textPosition = CGPoint(
            x: CGFloat(width) / 2 - bounds[index].midX,
            y: baselineOrigin + baselineOffsets[index]
        )
        CTLineDraw(lines[index], context)
    }

    guard let image = context.makeImage() else { fatalError("Cannot finish \(artwork.key)") }
    writePNG(image, to: assetRoot.appendingPathComponent("generated/\(artwork.key).png"))
    writePNG(image, to: assetRoot.appendingPathComponent("upload-ready/iphone-6.1-6.3/\(artwork.export)"))
    print("\(artwork.key): native \(width) × \(height), source \(screenshot.width) × \(screenshot.height), "
          + "screen scale \(screen.width / CGFloat(screenshot.width)), title cap height \(capitalHeight)px")
}

let selectedKeys = Set(CommandLine.arguments.dropFirst(2))
precondition(selectedKeys.isSubset(of: Set(artworks.map(\.key))), "Unknown artwork key")
for artwork in artworks where selectedKeys.isEmpty || selectedKeys.contains(artwork.key) {
    autoreleasepool { render(artwork) }
}
