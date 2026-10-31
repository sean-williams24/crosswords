import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Export the supplied icon without an alpha channel; preserve the source artwork.
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let kit = root.appendingPathComponent("docs/intervls-brand")
let sourceURL = kit.appendingPathComponent("IV-icon.png")
let sourceData = try Data(contentsOf: sourceURL)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let width = 1024
let height = 1024
let bytesPerRow = width * 4

func loadImage(_ data: Data) -> CGImage {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == width, image.height == height else {
        fatalError("The supplied icon must be a 1024 × 1024 image.")
    }
    return image
}

func pixels(_ image: CGImage) -> Data {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: bytesPerRow, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return Data(bytes: context.data!, count: bytesPerRow * height)
}

let originalPixels = pixels(loadImage(sourceData))
guard stride(from: 3, to: originalPixels.count, by: 4).allSatisfy({ originalPixels[$0] == 255 }) else {
    fatalError("The supplied icon has transparent pixels. Supply an opaque background before importing.")
}
let provider = CGDataProvider(data: originalPixels as CFData)!
let opaqueImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                          bytesPerRow: bytesPerRow, space: colorSpace,
                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                          provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
let encoded = NSMutableData()
let destination = CGImageDestinationCreateWithData(encoded, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, opaqueImage, nil)
guard CGImageDestinationFinalize(destination), pixels(loadImage(encoded as Data)) == originalPixels else {
    fatalError("The exported icon must preserve every visible source pixel.")
}

let canonical = kit.appendingPathComponent("intervls-icon.png")
let backup = kit.appendingPathComponent("intervls-icon-draft.png")
if !FileManager.default.fileExists(atPath: backup.path), FileManager.default.fileExists(atPath: canonical.path) {
    try FileManager.default.copyItem(at: canonical, to: backup)
}
try (encoded as Data).write(to: canonical, options: .atomic)
try (encoded as Data).write(to: root.appendingPathComponent("Backword/Resources/Assets.xcassets/AppIcon.appiconset/intervls-icon.png"), options: .atomic)
guard try Data(contentsOf: sourceURL) == sourceData else {
    fatalError("The original icon source must remain unchanged.")
}
print("Installed 1024 × 1024 opaque iOS icon; all source pixels preserved.")
