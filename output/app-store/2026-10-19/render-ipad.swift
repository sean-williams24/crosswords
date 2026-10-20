import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Rebuild from the original capture at the final upload dimensions.
// Run from any directory: swift render-ipad.swift /absolute/path/to/2026-10-19
let assetRoot = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : URL(fileURLWithPath: #filePath).deletingLastPathComponent().path)
let repository = assetRoot.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let sourceURL = assetRoot.appendingPathComponent("sources/ipad.png")
let fontURL = repository.appendingPathComponent("Backword/Resources/OutfitFonts/Outfit-Bold.ttf")
let width = 2064
let height = 2752
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

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

guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let screenshot = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let provider = CGDataProvider(url: fontURL as CFURL),
      let fontFace = CGFont(provider),
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
      ) else { fatalError("Cannot load the original capture, Outfit font, or rendering context") }
precondition(screenshot.width == 2064 && screenshot.height == 2752, "Use the original full-resolution capture")
context.setShouldAntialias(true)
context.interpolationQuality = .high

// These sRGB stops retain the current dark artwork palette.
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [0x196197, 0x165786, 0x0F4973, 0x083A5B, 0x012B45, 0x011B2D].map { color(UInt32($0)) } as CFArray,
    locations: [0, 0.10, 0.25, 0.50, 0.75, 1]
)!
context.drawLinearGradient(
    gradient, start: CGPoint(x: 0, y: height), end: .zero,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

let deviceTop: CGFloat = 438
let device = topRect(172, deviceTop, 1720, 2218)
let screen = topRect(252, 518, 1560, 2080)
let framePath = rounded(device, 120)

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
context.addPath(rounded(device.insetBy(dx: 5, dy: 5), 115))
context.setStrokeColor(color(0x151719))
context.setLineWidth(5)
context.strokePath()

// Draw the original screenshot directly, downsampling once to fit the frame.
context.saveGState()
context.addPath(rounded(screen, 38))
context.clip()
context.draw(screenshot, in: screen)
// Exclude the simulator resize handle, which overlays empty background at the corner.
let handleSize: CGFloat = 60
context.setFillColor(color(0x080808))
context.fill(CGRect(x: screen.maxX - handleSize, y: screen.minY,
                    width: handleSize, height: handleSize))
context.restoreGState()

// A small camera in the top bezel; no screen content is covered.
context.setFillColor(color(0x151A20))
context.fillEllipse(in: topRect(1024, 470, 16, 16))
context.setFillColor(color(0x193447))
context.fillEllipse(in: topRect(1029, 475, 6, 6))

// Core Text renders the title at final resolution instead of enlarging raster text.
let unitFont = CTFontCreateWithGraphicsFont(fontFace, 100, nil, nil)
let font = CTFontCreateWithGraphicsFont(fontFace, 100 * 56 / CTFontGetCapHeight(unitFont), nil, nil)
let captions = ["Your daily", "word game ritual"]
let baselineOffsets: [CGFloat] = [0, -82]
let lines = captions.map { caption -> CTLine in
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(0xFFFFFF)
    ]
    return CTLineCreateWithAttributedString(NSAttributedString(string: caption, attributes: attributes))
}
let bounds = lines.map { CTLineGetImageBounds($0, context) }
let blockBounds = bounds.enumerated().reduce(CGRect.null) { partial, item in
    partial.union(item.element.offsetBy(dx: 0, dy: baselineOffsets[item.offset]))
}
let desiredCenterY = CGFloat(height) - deviceTop / 2
let baselineOrigin = desiredCenterY - blockBounds.midY
context.textMatrix = .identity
for index in lines.indices {
    context.textPosition = CGPoint(
        x: CGFloat(width) / 2 - bounds[index].midX,
        y: baselineOrigin + baselineOffsets[index]
    )
    CTLineDraw(lines[index], context)
}

guard let image = context.makeImage() else { fatalError("Cannot finish the full-resolution composition") }
let master = assetRoot.appendingPathComponent("generated/ipad.png")
let upload = assetRoot.appendingPathComponent("upload-ready/ipad-13/05-ipad-2064x2752.png")
writePNG(image, to: master)
writePNG(image, to: upload)
print("Rendered native 2064 × 2752 master and upload PNG from the original capture")
print("Screen: 1560 × 2080, one downsample from 2064 × 2752; no enlarged draft")
print("Title: \(captions.joined(separator: " ")), cap height 56px, centered at y=\(deviceTop / 2)")
