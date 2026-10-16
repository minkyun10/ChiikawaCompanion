// Review-only animation renderer. No changes to the installed companion app.
import AppKit
import ImageIO
import UniformTypeIdentifiers

enum Angle: Int, CaseIterable {
    case front, rear
    var roots: [CGPoint] { [CGPoint(x: 116, y: 56), CGPoint(x: 144, y: 56)] }
    // Retain the reference gait, with depth recession for the larger reference-sized feet.
    // The leading foot stays at the same contact position; the other is hidden by the belly.
    var projection: CGPoint { CGPoint(x: -0.75, y: self == .front ? -1.1133333333333333 : 1.1133333333333333) }
}

struct Step {
    let travel: CGFloat
    let lift: CGFloat
    // Same path as the approved motion reference, starting with the first foot forward.
    static func sample(_ phase: Double) -> Step {
        Step(travel: CGFloat(cos(phase)) * 6,
             lift: CGFloat(max(0, -sin(phase))) * 4)
    }
}

let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let input = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))!
let source = input.cgImage!
let ink = NSColor(calibratedWhite: 0.015, alpha: 1)
let cream = NSColor(red: 0.976, green: 0.965, blue: 0.94, alpha: 1)

func bitmap(_ width: Int, _ height: Int, draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    draw()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ image: NSBitmapImageRep, _ name: String) {
    try! image.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}

var bodies: [Angle: NSImage] = [:]
let cellWidth = source.width / 2
for angle in Angle.allCases {
    let cropped = source.cropping(to: CGRect(x: angle.rawValue * cellWidth, y: 0,
                                            width: cellWidth, height: source.height))!
    let raw = NSBitmapImageRep(cgImage: cropped)
    var left = cellWidth, right = 0, top = source.height, bottom = 0
    for y in 0..<source.height {
        for x in 0..<cellWidth where (raw.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.4 {
            left = min(left, x); right = max(right, x)
            top = min(top, y); bottom = max(bottom, y)
        }
    }
    precondition(right > left && bottom > top)
    let height = bottom - top + 1
    let scale = 192 / CGFloat(height)
    var headLeft = right, headRight = left
    for y in (top + height / 5)...(top + height * 11 / 20) {
        for x in left...right where (raw.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.4 {
            headLeft = min(headLeft, x); headRight = max(headRight, x)
        }
    }
    let center = CGFloat(headLeft + headRight) / 2
    let registered = bitmap(256, 256) {
        NSImage(cgImage: cropped, size: NSSize(width: cellWidth, height: source.height)).draw(
            in: NSRect(x: 128 - center * scale,
                       y: 236 - CGFloat(source.height - top) * scale,
                       width: CGFloat(cellWidth) * scale, height: CGFloat(source.height) * scale),
            from: .zero, operation: .sourceOver, fraction: 1)
    }
    bodies[angle] = NSImage(cgImage: registered.cgImage!, size: NSSize(width: 256, height: 256))
}

// One rounded diagonal foot outline, with the broad short proportions of reference 1.
// It is never scaled by side, phase, direction or which foot is leading.
func footOutline() -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: -11, y: 5))
    path.curve(to: CGPoint(x: -22, y: -10), controlPoint1: CGPoint(x: -13, y: -1), controlPoint2: CGPoint(x: -26, y: -4))
    path.curve(to: CGPoint(x: -17, y: -25), controlPoint1: CGPoint(x: -25, y: -15), controlPoint2: CGPoint(x: -23, y: -23))
    path.curve(to: CGPoint(x: 0, y: -24), controlPoint1: CGPoint(x: -12, y: -31), controlPoint2: CGPoint(x: -4, y: -29))
    path.curve(to: CGPoint(x: 18, y: 1), controlPoint1: CGPoint(x: 7, y: -20), controlPoint2: CGPoint(x: 14, y: -7))
    // Reference 1 has a broad, short foot rather than a long leg.
    let proportions = NSAffineTransform()
    proportions.scaleX(by: 1, yBy: 0.85)
    path.transform(using: proportions as AffineTransform)
    return path
}

func footPosition(_ angle: Angle, _ side: Int, _ phase: Double) -> CGPoint {
    let step = Step.sample(phase + (side == 0 ? 0 : .pi))
    let root = angle.roots[side]
    return CGPoint(x: root.x + angle.projection.x * step.travel,
                   y: root.y + angle.projection.y * step.travel + step.lift)
}

func drawFoot(_ angle: Angle, side: Int, phase: Double) {
    let position = footPosition(angle, side, phase)
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: position.x, yBy: position.y)
    if angle == .rear { transform.scaleX(by: -1, yBy: 1) }
    transform.concat()
    let outline = footOutline()
    let fill = outline.copy() as! NSBezierPath
    // Open upper edge merges with the white belly rather than adding a seam.
    fill.line(to: CGPoint(x: 18, y: 18))
    fill.line(to: CGPoint(x: -11, y: 18)); fill.close()
    NSColor.white.setFill(); fill.fill()
    ink.setStroke(); outline.lineWidth = 4.2
    outline.lineCapStyle = .round; outline.lineJoinStyle = .round; outline.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

func drawCharacter(_ angle: Angle, phase: Double, in rect: NSRect, mirrored: Bool = false) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: rect.minX, yBy: rect.minY)
    transform.scaleX(by: rect.width / 256, yBy: rect.height / 256)
    if mirrored { transform.translateX(by: 256, yBy: 0); transform.scaleX(by: -1, yBy: 1) }
    transform.concat()
    // Perspective changes occlusion, never foot geometry or size.
    let firstTravel = Step.sample(phase).travel
    let nearerSide = (angle == .front ? firstTravel >= 0 : firstTravel < 0) ? 0 : 1
    drawFoot(angle, side: 1 - nearerSide, phase: phase)
    bodies[angle]!.draw(in: NSRect(x: 0, y: 0, width: 256, height: 256),
                        from: .zero, operation: .sourceOver, fraction: 1)
    drawFoot(angle, side: nearerSide, phase: phase)
    NSGraphicsContext.restoreGraphicsState()
}

func label(_ text: String, in rect: NSRect, size: CGFloat = 15) {
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
    (text as NSString).draw(in: rect, withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: ink,
        .paragraphStyle: paragraph])
}

typealias Direction = (String, Angle, Bool)
let directions: [Direction] = [("DOWN LEFT", .front, false), ("DOWN RIGHT", .front, true),
                               ("UP LEFT", .rear, false), ("UP RIGHT", .rear, true)]
let framesDirectory = output.appendingPathComponent("Frames", isDirectory: true)
try FileManager.default.createDirectory(at: framesDirectory, withIntermediateDirectories: true)
for direction in directions {
    for frame in 0..<12 {
        save(bitmap(256, 256) {
            drawCharacter(direction.1, phase: Double(frame) / 12 * 2 * .pi,
                          in: NSRect(x: 0, y: 0, width: 256, height: 256), mirrored: direction.2)
        }, "Frames/\(direction.0.lowercased().replacingOccurrences(of: " ", with: "-"))-\(String(format: "%02d", frame + 1)).png")
    }
}

save(bitmap(3300, 1240) {
    cream.setFill(); NSRect(x: 0, y: 0, width: 3300, height: 1240).fill()
    label("HACHIWARE — REFERENCE FOOT SIZE / MATCHED 12-FRAME WALK",
          in: NSRect(x: 0, y: 1191, width: 3300, height: 38), size: 29)
    label("LEFT STEP  1–6", in: NSRect(x: 190, y: 1150, width: 1536, height: 28), size: 20)
    label("RIGHT STEP  7–12 · SAME FOOT / SAME PATH", in: NSRect(x: 1726, y: 1150, width: 1536, height: 28), size: 20)
    for frame in 0..<12 {
        label(String(frame + 1), in: NSRect(x: 190 + frame * 256, y: 1114, width: 256, height: 24), size: 16)
    }
    for (row, direction) in directions.enumerated() {
        let y = 835 - row * 274
        label(direction.0, in: NSRect(x: 0, y: y + 116, width: 185, height: 28), size: 18)
        for frame in 0..<12 {
            drawCharacter(direction.1, phase: Double(frame) / 12 * 2 * .pi,
                          in: NSRect(x: 190 + frame * 256, y: y, width: 256, height: 256), mirrored: direction.2)
        }
    }
}, "hachiware-diagonal-matched-walk-v4.png")

// Larger front/rear sheets make it easier to inspect the feet without zooming a 48-frame sheet.
for angle in Angle.allCases {
    save(bitmap(1650, 640) {
        cream.setFill(); NSRect(x: 0, y: 0, width: 1650, height: 640).fill()
        for frame in 0..<12 {
            let x = 25 + (frame % 6) * 266, y = frame < 6 ? 340 : 30
            drawCharacter(angle, phase: Double(frame) / 12 * 2 * .pi,
                          in: NSRect(x: x, y: y, width: 256, height: 256))
            label(String(format: "%02d", frame + 1), in: NSRect(x: x, y: y - 22, width: 256, height: 24), size: 17)
        }
    }, "hachiware-diagonal-\(angle == .front ? "front" : "rear")-12-v4.png")
}

save(bitmap(1100, 660) {
    cream.setFill(); NSRect(x: 0, y: 0, width: 1100, height: 660).fill()
    for angle in Angle.allCases {
        let y = angle == .front ? 335 : 15
        for (column, frame) in [0, 6].enumerated() {
            let x = 210 + column * 430
            drawCharacter(angle, phase: Double(frame) / 12 * 2 * .pi,
                          in: NSRect(x: x, y: y, width: 300, height: 300))
            label(frame == 0 ? "01 · LEFT STEP" : "07 · RIGHT STEP",
                  in: NSRect(x: x, y: y - 9, width: 300, height: 23), size: 16)
        }
        label(angle == .front ? "FRONT" : "REAR", in: NSRect(x: 0, y: y + 135, width: 180, height: 25), size: 19)
    }
}, "hachiware-diagonal-opposite-step-check-v4.png")

let gifURL = output.appendingPathComponent("hachiware-diagonal-walk-preview-v4.gif")
let gif = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, 12, nil)!
CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for frame in 0..<12 {
    let image = bitmap(820, 650) {
        cream.setFill(); NSRect(x: 0, y: 0, width: 820, height: 650).fill()
        for (slot, direction) in directions.enumerated() {
            let x = (slot % 2) * 410 + 55, y = slot < 2 ? 337 : 12
            drawCharacter(direction.1, phase: Double(frame) / 12 * 2 * .pi,
                          in: NSRect(x: x, y: y + 22, width: 300, height: 300), mirrored: direction.2)
            label(direction.0, in: NSRect(x: x, y: y, width: 300, height: 22), size: 15)
        }
    }
    let duration = Double((frame + 1) * 136 / 12 - frame * 136 / 12) / 100
    CGImageDestinationAddImage(gif, image.cgImage!, [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: duration,
                                      kCGImagePropertyGIFUnclampedDelayTime: duration]] as CFDictionary)
}
precondition(CGImageDestinationFinalize(gif))

var maximumError: CGFloat = 0
for angle in Angle.allCases {
    for sample in 0..<720 {
        let phase = Double(sample) / 720 * 2 * .pi
        let left = footPosition(angle, 0, phase)
        let rightLater = footPosition(angle, 1, phase + .pi)
        maximumError = max(maximumError, abs((left.x - angle.roots[0].x) - (rightLater.x - angle.roots[1].x)))
        maximumError = max(maximumError, abs((left.y - angle.roots[0].y) - (rightLater.y - angle.roots[1].y)))
    }
}
precondition(maximumError < 1e-9)
let validation: [String: Any] = [
    "runtime_applied": false, "directions": 4, "frames_per_direction": 12,
    "preview_frames": 12, "cycle_milliseconds": 1360,
    "foot_geometry": "one fixed broad rounded outline; no per-side or per-phase scaling",
    "foot_path_bounds": NSStringFromRect(footOutline().bounds),
    "body_height_pixels": 192, "foot_stroke_pixels": 4.2,
    "reference_motion": "same phase, travel, lift and timing; additional depth recession preserves far-foot occlusion",
    "half_cycle_offset_frames": 6,
    "maximum_left_right_trajectory_error_pixels": maximumError,
    "artwork": "first image body and foot proportions; regenerated fixed front/rear bodies",
    "review_status": "pending user review"
]
try JSONSerialization.data(withJSONObject: validation, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("review-validation.json"))
print("Rendered four matched 12-frame diagonal directions. Left/right path error: \(maximumError).")
