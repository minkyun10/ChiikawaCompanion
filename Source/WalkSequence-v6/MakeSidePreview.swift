import AppKit
import ImageIO
import UniformTypeIdentifiers

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let source = CGImageSourceCreateWithURL(input as CFURL, nil)!
let count = CGImageSourceGetCount(source)
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, count, nil)!
CGImageDestinationSetProperties(destination,
    [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for frame in 0..<count {
    let original = CGImageSourceCreateImageAtIndex(source, frame, nil)!
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 220,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 400 * 4, bitsPerPixel: 32)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    for (column, sourceY) in [220, 0].enumerated() {
        let cropped = original.cropping(to: CGRect(x: 600, y: sourceY, width: 200, height: 220))!
        NSImage(cgImage: cropped, size: NSSize(width: 200, height: 220)).draw(
            in: NSRect(x: column * 200, y: 0, width: 200, height: 220),
            from: .zero, operation: .sourceOver, fraction: 1)
    }
    context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
    let properties = CGImageSourceCopyPropertiesAtIndex(source, frame, nil) as? [CFString: Any]
    let timing = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any] ?? [:]
    CGImageDestinationAddImage(destination, bitmap.cgImage!,
        [kCGImagePropertyGIFDictionary: timing] as CFDictionary)
}
precondition(CGImageDestinationFinalize(destination))
