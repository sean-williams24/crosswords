import AppKit
import CoreText
import CryptoKit
import Foundation
import ImageIO

// Import the supplied logos without recreating their lettering. App icons are managed separately.
let promotionalOnly = CommandLine.arguments.contains("--promotional-only")
let rootPath = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") } ?? FileManager.default.currentDirectoryPath
let root = URL(fileURLWithPath: rootPath)
let output = root.appendingPathComponent("docs/intervls-brand")
let assets = root.appendingPathComponent("Backword/Resources/Assets.xcassets")
let web = root.appendingPathComponent("web/public/brand")
let fm = FileManager.default
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let background = CGColor(srgbRed: 0.094, green: 0.094, blue: 0.094, alpha: 1)
// Opaque sRGB equivalent of the iOS Dark Mode Backword Home card (#293364).
let blue = CGColor(srgbRed: 41.0 / 255, green: 51.0 / 255, blue: 100.0 / 255, alpha: 1)
for directory in [output, web] { try fm.createDirectory(at: directory, withIntermediateDirectories: true) }

func bitmap(_ width: Int, _ height: Int, alpha: Bool) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
              space: colorSpace, bitmapInfo: alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue)!
}
func pngData(_ image: CGImage) -> Data {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}
func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

/// Image coordinates (top-left), with two source pixels of transparent safety padding.
func contentBounds(_ image: CGImage) -> CGRect {
    let context = bitmap(image.width, image.height, alpha: true)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
    var minX = image.width, minY = image.height, maxX = -1, maxY = -1
    for y in 0..<image.height { for x in 0..<image.width {
        if pixels[y * context.bytesPerRow + x * 4 + 3] > 0 {
            minX = min(minX, x); minY = min(minY, y)
            maxX = max(maxX, x); maxY = max(maxY, y)
        }
    }}
    precondition(maxX >= minX && maxY >= minY, "A logo source is empty")
    let left = max(0, minX - 2), top = max(0, minY - 2)
    let right = min(image.width, maxX + 3), bottom = min(image.height, maxY + 3)
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
}

struct LogoSource {
    let appearance: String
    let filename: String
    let originalData: Data
    let image: CGImage
    let embeddedPNG: Data
    let pdfPage: CGPDFPage?
    let crop: CGRect

    var quartzCrop: CGRect {
        CGRect(x: crop.minX, y: CGFloat(image.height) - crop.maxY, width: crop.width, height: crop.height)
    }
}
let lightURL = output.appendingPathComponent("intervls-light2.pdf")
let lightData = try Data(contentsOf: lightURL)
guard let lightDocument = CGPDFDocument(lightURL as CFURL), lightDocument.numberOfPages == 1,
      let lightPage = lightDocument.page(at: 1) else { fatalError("Provide the single-page intervls-light2.pdf") }
let lightBox = lightPage.getBoxRect(.mediaBox)
// 2x renders below the supplied PDF's embedded image resolution; no font rendering is involved.
let lightScale: CGFloat = 2
let lightContext = bitmap(Int(ceil(lightBox.width * lightScale)), Int(ceil(lightBox.height * lightScale)), alpha: true)
lightContext.scaleBy(x: lightScale, y: lightScale)
lightContext.translateBy(x: -lightBox.minX, y: -lightBox.minY)
lightContext.drawPDFPage(lightPage)
let lightImage = lightContext.makeImage()!
let light = LogoSource(appearance: "light", filename: "intervls-light2.pdf", originalData: lightData,
                       image: lightImage, embeddedPNG: pngData(lightImage), pdfPage: lightPage, crop: contentBounds(lightImage))
let darkURL = output.appendingPathComponent("intervls-dark2.png")
let darkData = try Data(contentsOf: darkURL)
guard let darkImageSource = CGImageSourceCreateWithURL(darkURL as CFURL, nil),
      let darkImage = CGImageSourceCreateImageAtIndex(darkImageSource, 0, nil) else { fatalError("Provide intervls-dark2.png") }
let dark = LogoSource(appearance: "dark", filename: "intervls-dark2.png", originalData: darkData,
                      image: darkImage, embeddedPNG: darkData, pdfPage: nil, crop: contentBounds(darkImage))
let sources = [light, dark]
let canvas = CGSize(width: 100 * dark.crop.width / dark.crop.height, height: 100)

func fittedRect(_ size: CGSize, within rect: CGRect) -> CGRect {
    let scale = min(rect.width / size.width, rect.height / size.height)
    let fitted = CGSize(width: size.width * scale, height: size.height * scale)
    return CGRect(x: rect.midX - fitted.width / 2, y: rect.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
}
func drawLogo(_ source: LogoSource, in rect: CGRect, context: CGContext) {
    let fitted = fittedRect(source.crop.size, within: rect)
    context.saveGState()
    context.clip(to: fitted)
    let scale = fitted.width / source.crop.width
    context.translateBy(x: fitted.minX - source.quartzCrop.minX * scale, y: fitted.minY - source.quartzCrop.minY * scale)
    context.scaleBy(x: scale, y: scale)
    if let page = source.pdfPage {
        context.scaleBy(x: lightScale, y: lightScale)
        context.translateBy(x: -lightBox.minX, y: -lightBox.minY)
        context.drawPDFPage(page)
    } else {
        context.interpolationQuality = .high
        context.draw(source.image, in: CGRect(x: 0, y: 0, width: source.image.width, height: source.image.height))
    }
    context.restoreGState()
}
func svg(_ source: LogoSource) -> String {
    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(canvas.width) \(canvas.height)" role="img" aria-label="Intervls"><svg width="100%" height="100%" viewBox="\(source.crop.minX) \(source.crop.minY) \(source.crop.width) \(source.crop.height)" preserveAspectRatio="xMidYMid meet"><image width="\(source.image.width)" height="\(source.image.height)" href="data:image/png;base64,\(source.embeddedPNG.base64EncodedString())"/></svg></svg>
    """
}
if !promotionalOnly {
    let logoSet = assets.appendingPathComponent("IntervlsLogo.imageset")
    let shareSet = assets.appendingPathComponent("IntervlsLogoShare.imageset")
    for directory in [logoSet, shareSet] { try fm.createDirectory(at: directory, withIntermediateDirectories: true) }
    for source in sources {
        let svgText = svg(source)
        for target in [web, output] {
            try svgText.write(to: target.appendingPathComponent("intervls-\(source.appearance).svg"), atomically: true, encoding: .utf8)
        }
        var box = CGRect(origin: .zero, size: canvas)
        let url = output.appendingPathComponent("intervls-\(source.appearance).pdf")
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { fatalError("Cannot write \(url.path)") }
        context.beginPDFPage(nil); drawLogo(source, in: box, context: context); context.endPDFPage(); context.closePDF()
        let target = logoSet.appendingPathComponent(url.lastPathComponent)
        if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
        try fm.copyItem(at: url, to: target)
    }
    let sharePDF = shareSet.appendingPathComponent("intervls-dark.pdf")
    if fm.fileExists(atPath: sharePDF.path) { try fm.removeItem(at: sharePDF) }
    try fm.copyItem(at: output.appendingPathComponent("intervls-dark.pdf"), to: sharePDF)
    let catalog: [String: Any] = [
        "images": [
            ["filename": "intervls-light.pdf", "idiom": "universal"],
            ["filename": "intervls-dark.pdf", "idiom": "universal", "appearances": [["appearance": "luminosity", "value": "dark"]]]
        ],
        "info": ["author": "xcode", "version": 1],
        "properties": ["preserves-vector-representation": true]
    ]
    try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys]).write(to: logoSet.appendingPathComponent("Contents.json"))
    try JSONSerialization.data(withJSONObject: ["images": [["filename": "intervls-dark.pdf", "idiom": "universal"]],
        "info": ["author": "xcode", "version": 1], "properties": ["preserves-vector-representation": true]],
        options: [.prettyPrinted, .sortedKeys]).write(to: shareSet.appendingPathComponent("Contents.json"))

}

// Outfit remains the app's tagline/body font. It is never used to recreate the supplied wordmark.
let fontURL = root.appendingPathComponent("web/public/fonts/Outfit-Bold.ttf")
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
func drawTagline(_ context: CGContext, center: CGPoint, size: CGFloat) {
    let font = CTFontCreateWithName("Outfit-Bold" as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Free daily word games to challenge your mind", attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): blue
    ]))
    let box = CTLineGetImageBounds(line, context)
    context.textPosition = CGPoint(x: center.x - box.midX, y: center.y - box.midY)
    CTLineDraw(line, context)
}
func poster(_ name: String, _ width: Int, _ height: Int, tagline: Bool = true) throws {
    let context = bitmap(width, height, alpha: false)
    context.setFillColor(background); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    // Do not enlarge the supplied raster wordmark, including in the largest promotional exports.
    let markWidth = min(CGFloat(width) * 0.7, dark.crop.width - 4)
    drawLogo(dark, in: CGRect(x: (CGFloat(width) - markWidth) / 2, y: CGFloat(height) * (tagline ? 0.47 : 0.28),
                             width: markWidth, height: CGFloat(height) * 0.38), context: context)
    if tagline { drawTagline(context, center: CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) * 0.28), size: CGFloat(width) * 0.034) }
    try pngData(context.makeImage()!).write(to: output.appendingPathComponent(name))
}
try poster("social-cover-1640x624.png", 1640, 624)
try poster("social-preview-1200x630.png", 1200, 630)
try poster("app-store-header-3840x1646.png", 3840, 1646)
try poster("app-store-header-5244x2950.png", 5244, 2950)
try poster("app-store-search-3840x2560.png", 3840, 2560, tagline: false)
let ogTarget = web.appendingPathComponent("intervls-social-preview.png")
if fm.fileExists(atPath: ogTarget.path) { try fm.removeItem(at: ogTarget) }
try fm.copyItem(at: output.appendingPathComponent("social-preview-1200x630.png"), to: ogTarget)
let manifest: [String: Any] = [
    "canvas": ["width": canvas.width, "height": canvas.height],
    "source_kind": "supplied raster artwork; PDF/SVG containers are not vector lettering",
    "icons_managed_separately": true,
    "sources": sources.map { source -> [String: Any] in
        ["appearance": source.appearance, "file": source.filename, "sha256": sha256(source.originalData),
         "image_width": source.image.width, "image_height": source.image.height,
         "crop": ["x": source.crop.minX, "y": source.crop.minY, "width": source.crop.width, "height": source.crop.height],
         "embedded_png_sha256": sha256(source.embeddedPNG)]
    }
]
if !promotionalOnly {
    try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("import-manifest.json"))
}
print(promotionalOnly ? "Refreshed promotional artwork only; wordmark and icon assets were not changed." : "Imported supplied Intervls light/dark logos and refreshed wordmark artwork. Icon assets were not changed.")
