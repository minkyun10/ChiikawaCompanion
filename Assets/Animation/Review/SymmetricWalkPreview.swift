// Review-only renderer. This file is outside the app target and does not change the running app.
import AppKit
import ImageIO
import UniformTypeIdentifiers

enum ViewAngle: Int, CaseIterable {
    case front, side, back, frontDiagonal, backDiagonal
    var cell: (Int, Int) {
        switch self {
        case .front: return (0, 0)
        case .side: return (1, 0)
        case .back: return (2, 0)
        case .frontDiagonal: return (0, 1)
        case .backDiagonal: return (1, 1)
        }
    }
    var projection: CGPoint {
        switch self {
        case .front: return CGPoint(x: 0, y: -0.35)
        case .back: return CGPoint(x: 0, y: 0.35)
        case .side: return CGPoint(x: -1, y: 0)
        case .frontDiagonal: return CGPoint(x: -0.75, y: -0.28)
        case .backDiagonal: return CGPoint(x: -0.75, y: 0.28)
        }
    }
    var footRoots: [CGPoint] {
        switch self {
        case .front, .back: return [CGPoint(x: 116, y: 46), CGPoint(x: 140, y: 46)]
        case .side: return [CGPoint(x: 128, y: 49), CGPoint(x: 132, y: 45)]
        case .frontDiagonal: return [CGPoint(x: 119, y: 47), CGPoint(x: 138, y: 44)]
        case .backDiagonal: return [CGPoint(x: 118, y: 45), CGPoint(x: 135, y: 48)]
        }
    }
}

struct Step: Equatable {
    let travel: CGFloat
    let lift: CGFloat
    // One and only one trajectory. Right-foot motion is this exact function half a cycle later.
    static func sample(_ phase: Double) -> Step {
        Step(travel: CGFloat(-cos(phase)) * 6,
             lift: CGFloat(max(0, sin(phase))) * 4)
    }
}

let ink = NSColor(calibratedWhite: 0.035, alpha: 1)
let cream = NSColor(red: 0.976, green: 0.965, blue: 0.94, alpha: 1)
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let sourceRep = NSBitmapImageRep(data: try Data(contentsOf: input))!
let atlas = sourceRep.cgImage!
precondition(atlas.width == 1536 && atlas.height == 1024)

func bitmap(_ width: Int, _ height: Int, draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    draw(); graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ name: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}

struct Body {
    let image: NSImage
    let leftArmX: CGFloat
    let rightArmX: CGFloat
    let tailRect: NSRect?
}
var bodies: [ViewAngle: Body] = [:]
for angle in ViewAngle.allCases {
    let (column, row) = angle.cell
    let cell = CGRect(x: column * 512, y: row * 512, width: 512, height: 512)
    let cropped = atlas.cropping(to: cell)!
    let raw = NSBitmapImageRep(cgImage: cropped)
    var left = 512, right = 0, top = 512, bottom = 0
    var tailLeft = 512, tailRight = 0, tailTop = 512, tailBottom = 0
    for y in 0..<512 {
        for x in 0..<512 where (raw.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.25 {
            left = min(left, x); right = max(right, x)
            top = min(top, y); bottom = max(bottom, y)
            if y > 300, let color = raw.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
               color.blueComponent - color.redComponent > 0.1,
               color.greenComponent - color.redComponent > 0.05 {
                tailLeft = min(tailLeft, x); tailRight = max(tailRight, x)
                tailTop = min(tailTop, y); tailBottom = max(tailBottom, y)
            }
        }
    }
    let h = CGFloat(bottom - top + 1), scale: CGFloat = 192 / h
    var headLeft = right, headRight = left
    for y in (top + Int(h * 0.2))...(top + Int(h * 0.55)) {
        for x in left...right where (raw.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.25 {
            headLeft = min(headLeft, x); headRight = max(headRight, x)
        }
    }
    let headCenter = CGFloat(headLeft + headRight) / 2
    let rect = NSRect(x: 128 - headCenter * scale, y: 236 - CGFloat(512 - top) * scale,
                      width: 512 * scale, height: 512 * scale)
    let registered = bitmap(256, 256) {
        NSImage(cgImage: cropped, size: NSSize(width: 512, height: 512))
            .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }
    // Locate the arm attachment points on the fixed silhouette, not from moving limbs.
    let armRow = top + Int((236 - 105) / scale)
    var armLeft = right, armRight = left
    for x in left...right where (raw.colorAt(x: x, y: armRow)?.alphaComponent ?? 0) > 0.25 {
        armLeft = min(armLeft, x); armRight = max(armRight, x)
    }
    let tailRect: NSRect? = tailRight > tailLeft ? NSRect(
        x: rect.minX + CGFloat(tailLeft) * scale - 4,
        y: 236 - CGFloat(tailBottom - top + 1) * scale - 4,
        width: CGFloat(tailRight - tailLeft + 1) * scale + 8,
        height: CGFloat(tailBottom - tailTop + 1) * scale + 8) : nil
    bodies[angle] = Body(image: NSImage(cgImage: registered.cgImage!, size: NSSize(width: 256, height: 256)),
                        leftArmX: 128 + (CGFloat(armLeft) - headCenter) * scale,
                        rightArmX: 128 + (CGFloat(armRight) - headCenter) * scale,
                        tailRect: tailRect)
}

func at(_ point: CGPoint, mirror: Bool = false, rotation: CGFloat = 0, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: point.x, yBy: point.y)
    transform.rotate(byRadians: rotation)
    if mirror { transform.scaleX(by: -1, yBy: 1) }
    transform.concat(); draw()
    NSGraphicsContext.restoreGraphicsState()
}

func foot() {
    // Both feet use the SAME path, dimensions, outline and fill; no per-frame anatomy changes.
    let outline = NSBezierPath()
    outline.move(to: CGPoint(x: -7, y: 0))
    outline.curve(to: CGPoint(x: -5, y: -11), controlPoint1: CGPoint(x: -8, y: -5), controlPoint2: CGPoint(x: -8, y: -8))
    outline.curve(to: CGPoint(x: 5, y: -11), controlPoint1: CGPoint(x: -2, y: -15), controlPoint2: CGPoint(x: 2, y: -15))
    outline.curve(to: CGPoint(x: 7, y: 0), controlPoint1: CGPoint(x: 8, y: -8), controlPoint2: CGPoint(x: 8, y: -5))
    let fill = outline.copy() as! NSBezierPath
    fill.line(to: CGPoint(x: 7, y: 11)); fill.line(to: CGPoint(x: -7, y: 11)); fill.close()
    NSColor.white.setFill(); fill.fill()
    ink.setStroke(); outline.lineWidth = 4.2; outline.lineCapStyle = .round; outline.lineJoinStyle = .round
    outline.stroke()
}

func outerArm() {
    let outline = NSBezierPath()
    outline.move(to: CGPoint(x: 0, y: 7))
    outline.curve(to: CGPoint(x: -9, y: -10), controlPoint1: CGPoint(x: -8, y: 5), controlPoint2: CGPoint(x: -14, y: -6))
    outline.curve(to: CGPoint(x: 1, y: -6), controlPoint1: CGPoint(x: -6, y: -16), controlPoint2: CGPoint(x: 0, y: -11))
    let fill = outline.copy() as! NSBezierPath
    fill.line(to: CGPoint(x: 8, y: -5)); fill.line(to: CGPoint(x: 8, y: 10)); fill.close()
    NSColor.white.setFill(); fill.fill()
    ink.setStroke(); outline.lineWidth = 4.2; outline.lineCapStyle = .round; outline.stroke()
}

func innerArm() {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: -7, y: 5))
    path.curve(to: CGPoint(x: 5, y: -6), controlPoint1: CGPoint(x: -11, y: -7), controlPoint2: CGPoint(x: -1, y: -12))
    path.curve(to: CGPoint(x: 7, y: 5), controlPoint1: CGPoint(x: 10, y: -3), controlPoint2: CGPoint(x: 9, y: 1))
    ink.setStroke(); path.lineWidth = 4.2; path.lineCapStyle = .round; path.stroke()
}

func footPosition(_ angle: ViewAngle, _ side: Int, _ phase: Double) -> CGPoint {
    let step = Step.sample(phase + (side == 0 ? 0 : .pi))
    let root = angle.footRoots[side], direction = angle.projection
    return CGPoint(x: root.x + direction.x * step.travel,
                   y: root.y + direction.y * step.travel + step.lift)
}

func drawCharacter(_ angle: ViewAngle, phase: Double, in rect: NSRect, mirrored: Bool = false) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: rect.minX, yBy: rect.minY)
    transform.scaleX(by: rect.width / 256, yBy: rect.height / 256)
    if mirrored { transform.translateX(by: 256, yBy: 0); transform.scaleX(by: -1, yBy: 1) }
    transform.concat()
    let body = bodies[angle]!
    body.image.draw(in: NSRect(x: 0, y: 0, width: 256, height: 256), from: .zero, operation: .sourceOver, fraction: 1)
    // Lower-body parts alone change. The body, crown, eyes, cheeks and tail never change.
    for side in 0..<2 { at(footPosition(angle, side, phase)) { foot() } }
    // The stationary tail occludes the feet; moving legs must never repaint its pixels.
    if let tailRect = body.tailRect {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: tailRect).addClip()
        body.image.draw(in: NSRect(x: 0, y: 0, width: 256, height: 256), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }
    let leftSwing = CGFloat(cos(phase)) * 0.035
    let rightSwing = CGFloat(cos(phase + .pi)) * 0.035
    switch angle {
    case .front, .back:
        at(CGPoint(x: body.leftArmX + 3, y: 105), rotation: leftSwing) { outerArm() }
        at(CGPoint(x: body.rightArmX - 3, y: 105), mirror: true, rotation: rightSwing) { outerArm() }
    case .side:
        at(CGPoint(x: 137, y: 95), rotation: rightSwing) { innerArm() }
    case .frontDiagonal:
        at(CGPoint(x: body.leftArmX + 3, y: 105), rotation: leftSwing) { outerArm() }
        at(CGPoint(x: body.rightArmX - 17, y: 97), rotation: rightSwing) { innerArm() }
    case .backDiagonal:
        at(CGPoint(x: body.leftArmX + 3, y: 105), rotation: leftSwing) { outerArm() }
    }
    NSGraphicsContext.restoreGraphicsState()
}

func label(_ text: String, in rect: NSRect, size: CGFloat = 13, color: NSColor = ink, centered: Bool = true) {
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = centered ? .center : .left
    (text as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium),
                                                     .foregroundColor: color, .paragraphStyle: paragraph])
}

typealias Direction = (String, ViewAngle, Bool)
let cardinal: [Direction] = [("FRONT / DOWN", .front, false), ("BACK / UP", .back, false),
                            ("LEFT", .side, false), ("RIGHT", .side, true)]
let diagonal: [Direction] = [("DOWN LEFT", .frontDiagonal, false), ("DOWN RIGHT", .frontDiagonal, true),
                            ("UP LEFT", .backDiagonal, false), ("UP RIGHT", .backDiagonal, true)]
func contactSheet(_ directions: [Direction], name: String) {
    let width = 2100, height = 850
    save(bitmap(width, height) {
        cream.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
        label("HACHIWARE — MATCHED LEFT / RIGHT WALK", in: NSRect(x: 0, y: 798, width: width, height: 34), size: 26)
        label("LEFT FOOT  1–6", in: NSRect(x: 170, y: 757, width: 960, height: 24), size: 17)
        label("RIGHT FOOT  7–12  ·  SAME PATH, HALF-CYCLE OFFSET", in: NSRect(x: 1130, y: 757, width: 960, height: 24), size: 17)
        for frame in 0..<12 {
            label(String(frame + 1), in: NSRect(x: 170 + frame * 160, y: 725, width: 160, height: 20), size: 12)
        }
        for (row, direction) in directions.enumerated() {
            let y = 540 - row * 178
            label(direction.0, in: NSRect(x: 6, y: y + 70, width: 158, height: 24), size: 14)
            for frame in 0..<12 {
                drawCharacter(direction.1, phase: Double(frame) / 12 * 2 * .pi,
                    in: NSRect(x: 170 + frame * 160, y: y, width: 160, height: 170), mirrored: direction.2)
            }
        }
    }, name)
}
contactSheet(cardinal, name: "hachiware-symmetric-cardinal-sheet-v1.png")
contactSheet(diagonal, name: "hachiware-symmetric-diagonal-sheet-v1.png")

save(bitmap(3072, 1280) {
    for (row, angle) in ViewAngle.allCases.enumerated() {
        for frame in 0..<12 {
            drawCharacter(angle, phase: Double(frame) / 12 * 2 * .pi,
                          in: NSRect(x: frame * 256, y: (4 - row) * 256, width: 256, height: 256))
        }
    }
}, "hachiware-symmetric-walk-atlas-v1.png")

let gifURL = output.appendingPathComponent("hachiware-symmetric-walk-preview-v1.gif")
let gif = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, 48, nil)!
CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let allDirections = cardinal + diagonal
for frame in 0..<48 {
    let rep = bitmap(800, 460) {
        cream.setFill(); NSRect(x: 0, y: 0, width: 800, height: 460).fill()
        for (slot, direction) in allDirections.enumerated() {
            let x = (slot % 4) * 200, y = slot < 4 ? 230 : 0
            drawCharacter(direction.1, phase: Double(frame) / 48 * 2 * .pi,
                in: NSRect(x: x + 10, y: y + 32, width: 180, height: 180), mirrored: direction.2)
            label(direction.0, in: NSRect(x: x, y: y + 10, width: 200, height: 18), size: 11)
        }
    }
    let totalCentiseconds = 136
    let delay = Double((frame + 1) * totalCentiseconds / 48 - frame * totalCentiseconds / 48) / 100
    CGImageDestinationAddImage(gif, rep.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
}
precondition(CGImageDestinationFinalize(gif))

// Validate anatomical interchange: both limbs sample the same path exactly half a cycle apart.
var maximumError: CGFloat = 0
for angle in ViewAngle.allCases {
    for sample in 0..<720 {
        let phase = Double(sample) / 720 * 2 * .pi
        let left = footPosition(angle, 0, phase)
        let rightHalfCycleLater = footPosition(angle, 1, phase + .pi)
        let leftRoot = angle.footRoots[0], rightRoot = angle.footRoots[1]
        maximumError = max(maximumError, abs((left.x - leftRoot.x) - (rightHalfCycleLater.x - rightRoot.x)))
        maximumError = max(maximumError, abs((left.y - leftRoot.y) - (rightHalfCycleLater.y - rightRoot.y)))
    }
}
precondition(maximumError < 1e-9)
print("Exported review sheets, 60-frame atlas and 8-direction GIF. Left/right trajectory error: \(maximumError)")
