import AppKit

// Packs approved, already registered 256-pixel frames without changing character geometry.
let input = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 3072, pixelsHigh: 256,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 3072 * 4, bitsPerPixel: 32)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
graphics.imageInterpolation = .none
for direction in ["down-left"] {
    for frame in 0..<12 {
        let path = input.appendingPathComponent("\(direction)-\(String(format: "%02d", frame + 1)).png")
        guard let image = NSImage(contentsOf: path) else { fatalError("Missing approved frame: \(path.lastPathComponent)") }
        image.draw(in: NSRect(x: frame * 256, y: 0, width: 256, height: 256),
                   from: .zero, operation: .sourceOver, fraction: 1)
    }
}
graphics.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
print("Packed approved diagonal atlas: \(output.lastPathComponent)")
