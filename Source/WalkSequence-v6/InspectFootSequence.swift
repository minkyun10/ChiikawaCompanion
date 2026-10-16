import AppKit
let source = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))!.cgImage!
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let result = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1380, pixelsHigh: 460,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 1380 * 4, bitsPerPixel: 32)!
let context = NSGraphicsContext(bitmapImageRep: result)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1380, height: 460).fill()
for frame in 0..<12 {
    let column = frame % 6, row = frame / 6
    let crop = source.cropping(to: CGRect(x: column * 300 + 90, y: 230 + row * 330,
                                          width: 115, height: 90))!
    let x = column * 230, y = (1 - row) * 230 + 40
    NSImage(cgImage: crop, size: NSSize(width: 115, height: 90)).draw(
        in: NSRect(x: x, y: y, width: 230, height: 180), from: .zero, operation: .sourceOver, fraction: 1)
    (String(frame + 1) as NSString).draw(at: NSPoint(x: x + 105, y: y - 28),
        withAttributes: [.font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor.black])
}
context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
try result.representation(using: .png, properties: [:])!.write(to: output)
