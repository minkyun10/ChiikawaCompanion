import AppKit

// Registration/cropping only. The new artwork itself comes from the built-in image generator.
let args = CommandLine.arguments
guard args.count == 4 else { fatalError("Usage: PrepareDailyAtlas <generated.png> <action-name> <output-directory>") }
let source = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: args[1])))!.cgImage!
let name = args[2], output = URL(fileURLWithPath: args[3], isDirectory: true)
try FileManager.default.createDirectory(at: output.appendingPathComponent("Frames"), withIntermediateDirectories: true)
struct Cell { let image: CGImage; let hair: CGRect; let bounds: CGRect }
var cells: [Cell] = []
// Generated sheets can have unequal row gutters. Locate the real transparent
// separator rather than cutting a paw or table at an assumed one-third line.
let full = NSBitmapImageRep(cgImage: source)
func rowCut(_ fraction: Double) -> Int {
    let expected = Int(Double(source.height) * fraction)
    let radius = Int(Double(source.height) * 0.09)
    var runs: [(Int, Int)] = [], start: Int?
    for y in max(1, expected-radius)..<min(source.height-1, expected+radius) {
        let quiet = (0..<source.width).allSatisfy { (full.colorAt(x: $0, y: y)?.alphaComponent ?? 0) < 0.05 }
        if quiet && start == nil { start = y }
        if !quiet, let first = start { runs.append((first, y-1)); start = nil }
    }
    if let first = start { runs.append((first, min(source.height-2, expected+radius-1))) }
    guard let gap = runs.max(by: { ($0.1-$0.0) < ($1.1-$1.0) }) else {
        fatalError("No clean transparent row separator near \(fraction)")
    }
    return (gap.0+gap.1)/2
}
let rowEdges = [0, source.height/3, 2*source.height/3, source.height]
for index in 0..<12 {
    let col = index % 4, row = index / 4
    let x0 = col * source.width / 4, x1 = (col + 1) * source.width / 4
    let y0 = rowEdges[row], y1 = rowEdges[row+1]
    let crop = source.cropping(to: CGRect(x: x0, y: y0, width: x1-x0, height: y1-y0))!
    let rep = NSBitmapImageRep(cgImage: crop)
    var hair = CGRect.null, bounds = CGRect.null
    for y in 0..<crop.height { for x in 0..<crop.width {
        guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.25 else { continue }
        let pixel = CGRect(x: x, y: y, width: 1, height: 1)
        bounds = bounds.union(pixel)
        if y < crop.height / 2 && c.alphaComponent > 0.8 && c.blueComponent - c.redComponent > 0.08
            && c.greenComponent - c.redComponent > 0.04 && c.redComponent < 0.72 {
            hair = hair.union(pixel)
        }
    } }
    precondition(!hair.isNull && hair.width > 40 && !bounds.isNull, "Missing character/hair in frame \(index+1)")
    precondition(bounds.minX > 0 && bounds.minY > 0 && bounds.maxX < CGFloat(crop.width)
                 && bounds.maxY < CGFloat(crop.height), "Drawing touches a cell boundary in frame \(index+1)")
    cells.append(Cell(image: crop, hair: hair, bounds: bounds))
}
let hairWidth: CGFloat = cells.reduce(130) { value, cell in
    let radius = max(cell.hair.midX - cell.bounds.minX, cell.bounds.maxX - cell.hair.midX)
    let depth = cell.bounds.maxY - cell.hair.minY
    return min(value, 116 * cell.hair.width / radius, 222 * cell.hair.width / depth)
}
func bitmap(width: Int, height: Int, draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    context.imageInterpolation = .high; draw(); context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
    return rep
}
var frames: [NSImage] = [], registrations: [[String: Any]] = []
for (index, cell) in cells.enumerated() {
    let scale = hairWidth / cell.hair.width
    let rep = bitmap(width: 256, height: 256) {
        NSImage(cgImage: cell.image, size: NSSize(width: cell.image.width, height: cell.image.height)).draw(in:
            NSRect(x: 128 - cell.hair.midX * scale,
                   y: 236 - (CGFloat(cell.image.height) - cell.hair.minY) * scale,
                   width: CGFloat(cell.image.width) * scale, height: CGFloat(cell.image.height) * scale))
    }
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: output.appendingPathComponent(String(format: "Frames/%@-%02d.png", name, index+1)))
    frames.append(NSImage(cgImage: rep.cgImage!, size: NSSize(width: 256, height: 256)))
    registrations.append(["frame": index+1, "scale": scale, "hair_width_source": cell.hair.width,
                          "source_bounds": [cell.bounds.minX, cell.bounds.minY, cell.bounds.width, cell.bounds.height]])
}
let atlas = bitmap(width: 1536, height: 512) {
    for (index, frame) in frames.enumerated() {
        frame.draw(in: NSRect(x: index % 6 * 256, y: (1-index / 6)*256, width: 256, height: 256))
    }
}
try atlas.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("hachiware-\(name)-v16.png"))
let report: [String: Any] = ["action": name, "frames": 12, "source_columns": 4, "source_rows": 3,
    "source_row_edges": rowEdges, "runtime_columns": 6, "runtime_rows": 2, "runtime_cell": 256, "crown_top": 20,
    "registered_hair_width": hairWidth, "registrations": registrations]
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("\(name)-registration.json"))
print("Registered \(name): 12 chronological frames, hair width \(hairWidth), fixed crown anchor.")
