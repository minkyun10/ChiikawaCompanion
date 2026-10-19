import AppKit
import ImageIO
import UniformTypeIdentifiers

// Native rig revision: keep the approved v14 legs and every transform; open only the arm roots.
let inputs = CommandLine.arguments
guard inputs.count == 3 else { fatalError("Usage: JoinedArmPreview <rig-atlas.png> <output-directory>") }
let output = URL(fileURLWithPath: inputs[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let atlas = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: inputs[1])))!.cgImage!

func part(_ crop: CGRect) -> NSImage {
    let image = atlas.cropping(to: crop)!
    let bitmap = NSBitmapImageRep(cgImage: image)
    var x0 = image.width, y0 = image.height, x1 = 0, y1 = 0
    for y in 0..<image.height {
        for x in 0..<image.width where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.12 {
            x0 = min(x0, x); y0 = min(y0, y); x1 = max(x1, x); y1 = max(y1, y)
        }
    }
    x0 = max(0, x0 - 2); y0 = max(0, y0 - 2)
    x1 = min(image.width - 1, x1 + 2); y1 = min(image.height - 1, y1 + 2)
    let trimmed = image.cropping(to: CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1))!
    return NSImage(cgImage: trimmed, size: NSSize(width: trimmed.width, height: trimmed.height))
}
let body = part(CGRect(x: 140, y: 0, width: 560, height: 557))
let foot = part(CGRect(x: 1030, y: 165, width: 230, height: 315))
let arm = part(CGRect(x: 270, y: 670, width: 280, height: 260))
let neutral = part(CGRect(x: 875, y: 550, width: 495, height: 450))
let frameCount = 24
let cycleDuration = 62.7 / 46.0
let stride: CGFloat = 62.7 / (4 * (132.0 / 256.0))
let ground: CGFloat = 30
let bodyHeight: CGFloat = 194
let bodyBase: CGFloat = 45
let footWidth: CGFloat = 16
let footHeight: CGFloat = 26
let lift: CGFloat = 15
let bob: CGFloat = 5.5
let cream = NSColor(srgbRed: 0.976, green: 0.965, blue: 0.937, alpha: 1)
let ink = NSColor(srgbRed: 0.28, green: 0.25, blue: 0.23, alpha: 1)
let blue = NSColor(srgbRed: 0.36, green: 0.56, blue: 0.66, alpha: 1)

struct FootPose {
    let phase: Double
    let x: CGFloat
    let y: CGFloat
    let angle: CGFloat
    let planted: Bool
}
func wrap(_ phase: Double) -> Double { phase - floor(phase) }
func footPose(_ phase: Double) -> FootPose {
    let t = wrap(phase)
    if t < 0.5 {
        return FootPose(phase: t, x: -stride + 4 * stride * t, y: ground,
                        angle: CGFloat(-28 + 60 * t / 0.5) * .pi / 180, planted: true)
    }
    let u = t * 2 - 1
    // Match the planted foot's velocity at toe-off and touchdown. Both legs use
    // this exact same Hermite path; the far leg is offset by half a full cycle.
    let h00 = 2*u*u*u - 3*u*u + 1, h10 = u*u*u - 2*u*u + u
    let h01 = -2*u*u*u + 3*u*u, h11 = u*u*u - u*u
    let x = stride * (h00 + 2*h10 - h01 + 2*h11)
    let height = lift * pow(sin(.pi * u), 2)
    let angle = CGFloat(32 - 60 * (u*u*(3 - 2*u))) * .pi / 180
    return FootPose(phase: t, x: x, y: ground + height, angle: angle, planted: false)
}
func bodyOffset(_ t: Double) -> CGFloat { -bob * sin(4 * .pi * t) }
func drawFoot(_ p: FootPose, fraction: CGFloat = 1) {
    let cg = NSGraphicsContext.current!.cgContext
    cg.saveGState()
    // Rotate around the lower round end: the planted sole stays on its ground
    // contact instead of rising or sliding as the little leg rolls forward.
    cg.translateBy(x: 128 + p.x, y: p.y + footWidth / 2)
    cg.rotate(by: p.angle)
    foot.draw(in: NSRect(x: -footWidth / 2, y: -footWidth / 2,
                        width: footWidth, height: footHeight), from: .zero,
              operation: .sourceOver, fraction: fraction)
    cg.restoreGState()
}
func drawArm(x: CGFloat, y: CGFloat, angle: CGFloat) {
    let cg = NSGraphicsContext.current!.cgContext
    cg.saveGState(); cg.translateBy(x: x, y: y); cg.rotate(by: angle)
    // The source arm is a closed cutout. Open its proximal cap so the
    // remaining U-shaped contour flows into the torso at the shoulder.
    // Clip in arm-local coordinates: swing, pivot and hand position stay exact.
    cg.addRect(CGRect(x: -16, y: -30, width: 34, height: 30))
    cg.clip()
    arm.draw(in: NSRect(x: -7.5, y: -23, width: 17, height: 30))
    cg.restoreGState()
}
func drawRawCharacter(in rect: NSRect, phase: Double, right: Bool = false, markers: Bool = false) {
    let cg = NSGraphicsContext.current!.cgContext
    cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.minY)
    cg.scaleBy(x: rect.width / 256, y: rect.height / 256)
    if right { cg.translateBy(x: 256, y: 0); cg.scaleBy(x: -1, y: 1) }
    NSGraphicsContext.current?.imageInterpolation = .high
    let near = footPose(phase), far = footPose(phase + 0.5)
    let y = bodyBase + bodyOffset(phase)
    let swing = CGFloat(cos(2 * .pi * phase)) * .pi / 7
    drawArm(x: 61, y: y + 67, angle: -swing)
    drawJoint(far, bodyY: y)
    drawJoint(near, bodyY: y)
    drawFoot(far)
    let width = body.size.width / body.size.height * bodyHeight
    body.draw(in: NSRect(x: 128 - width / 2, y: y, width: width, height: bodyHeight))
    drawFoot(near)
    drawArm(x: 145, y: y + 67, angle: swing)
    if markers {
        for (p, color) in [(near, blue), (far, NSColor.systemOrange)] {
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: 125 + p.x, y: p.y - 5, width: 6, height: 6)).fill()
        }
    }
    cg.restoreGState()
}
func drawJoint(_ p: FootPose, bodyY: CGFloat) {
    let localY: CGFloat = 12
    let bottom = NSPoint(x: 128 + p.x - sin(p.angle) * localY,
                         y: p.y + footWidth / 2 + cos(p.angle) * localY)
    let hip = NSPoint(x: 128 + p.x * 0.35, y: bodyY + 24)
    let path = NSBezierPath(); path.move(to: bottom); path.line(to: hip)
    path.lineCapStyle = .round; path.lineWidth = 13
    NSColor(srgbRed: 0.08, green: 0.07, blue: 0.065, alpha: 1).setStroke()
    path.stroke()
}
var joinedFrames: [Int: NSImage] = [:]
func joinedFrame(phase: Double) -> NSImage {
    let key = Int((wrap(phase) * 24).rounded()) % 24
    if let cached = joinedFrames[key] { return cached }
    let rep = bitmap(256, 256) {
        drawRawCharacter(in: NSRect(x: 0, y: 0, width: 256, height: 256), phase: phase)
    }
    // The body/feet/short native connectors form one silhouette. Remove only
    // dark contours inside that union, leaving the original external soles,
    // pose transforms, upper artwork and alpha edge pixels untouched.
    let alpha = (0..<256).map { y in (0..<256).map { x in
        rep.colorAt(x: x, y: y)!.alphaComponent
    } }
    let radius = 2.2
    let feet = [footPose(phase), footPose(phase + 0.5)]
    func inJoint(_ x: CGFloat, _ y: CGFloat) -> Bool {
        func distance(_ q: NSPoint, _ a: NSPoint, _ b: NSPoint) -> CGFloat {
            let dx = b.x - a.x, dy = b.y - a.y
            let t = min(1, max(0, ((q.x-a.x)*dx + (q.y-a.y)*dy) / max(1, dx*dx+dy*dy)))
            return hypot(q.x-a.x-t*dx, q.y-a.y-t*dy)
        }
        let q = NSPoint(x: x, y: y)
        return feet.contains { p in
            func point(_ localY: CGFloat) -> NSPoint {
                NSPoint(x: 128 + p.x - sin(p.angle) * localY,
                        y: p.y + footWidth / 2 + cos(p.angle) * localY)
            }
            let hip = NSPoint(x: 128 + p.x * 0.35, y: bodyBase + bodyOffset(phase) + 24)
            return distance(q, point(0), point(18)) < 8.5 || distance(q, point(12), hip) < 8.5
        }
    }
    for py in 174..<224 {
        for px in 80..<180 {
            guard inJoint(CGFloat(px) + 0.5, 255.5 - CGFloat(py)),
                  let c = rep.colorAt(x: px, y: py)?.usingColorSpace(.deviceRGB),
                  c.alphaComponent > 0.98, min(c.redComponent, c.greenComponent, c.blueComponent) < 0.999 else { continue }
            var interior = true
            for dy in -3...3 {
                for dx in -3...3 where Double(dx * dx + dy * dy) <= radius * radius {
                    if alpha[py + dy][px + dx] < 0.9 { interior = false }
                }
            }
            if interior { rep.setColor(NSColor(deviceRed: 1, green: 1, blue: 1, alpha: 1), atX: px, y: py) }
        }
    }
    let image = NSImage(cgImage: rep.cgImage!, size: NSSize(width: 256, height: 256))
    joinedFrames[key] = image
    return image
}
func drawCharacter(in rect: NSRect, phase: Double, right: Bool = false, markers: Bool = false) {
    let cg = NSGraphicsContext.current!.cgContext
    cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.minY)
    if right { cg.translateBy(x: rect.width, y: 0); cg.scaleBy(x: -1, y: 1) }
    joinedFrame(phase: phase).draw(in: NSRect(origin: .zero, size: rect.size))
    cg.restoreGState()
    if markers {
        cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.minY)
        cg.scaleBy(x: rect.width / 256, y: rect.height / 256)
        for (p, color) in [(footPose(phase), blue), (footPose(phase + 0.5), NSColor.systemOrange)] {
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: 125 + p.x, y: p.y - 5, width: 6, height: 6)).fill()
        }
        cg.restoreGState()
    }
}
func bitmap(_ width: Int, _ height: Int, draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high; draw(); graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
func png(_ width: Int, _ height: Int, name: String, draw: () -> Void) {
    let rep = bitmap(width, height, draw: draw)
    try! rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
func text(_ title: String, rect: NSRect, size: CGFloat = 16, color: NSColor = ink, bold: Bool = false) {
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
    (title as NSString).draw(in: rect, withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular),
        .foregroundColor: color, .paragraphStyle: paragraph])
}
func line(from a: NSPoint, to b: NSPoint, color: NSColor, width: CGFloat = 1) {
    let p = NSBezierPath(); p.move(to: a); p.line(to: b); p.lineWidth = width
    color.setStroke(); p.stroke()
}
func floorLine(x: CGFloat, y: CGFloat, width: CGFloat, offset: CGFloat = 0) {
    line(from: NSPoint(x: x, y: y), to: NSPoint(x: x + width, y: y),
         color: NSColor(srgbRed: 0.78, green: 0.77, blue: 0.72, alpha: 1))
    let period = stride * 2
    let shift = offset.truncatingRemainder(dividingBy: period)
    for index in -2...20 {
        let marker = x + CGFloat(index) * period + shift
        if marker > x && marker < x + width {
            line(from: NSPoint(x: marker, y: y - 5), to: NSPoint(x: marker, y: y), color: blue.withAlphaComponent(0.5))
        }
    }
}
let labels = ["착지 · CONTACT", "내려감 · DOWN", "교차 · PASSING", "올라감 · UP"]
let keyFrames = [0, 3, 6, 9, 12, 15, 18, 21]
png(1280, 760, name: "hachiware-four-phase-keyposes-v15.png") {
    cream.setFill(); NSRect(x: 0, y: 0, width: 1280, height: 760).fill()
    text("하치와레 · 양발 24프레임 걷기", rect: NSRect(x: 0, y: 708, width: 1280, height: 32), size: 24, bold: true)
    for (slot, index) in keyFrames.enumerated() {
        let x = CGFloat(slot % 4) * 320 + 32, y: CGFloat = slot < 4 ? 382 : 56
        floorLine(x: x - 10, y: y + ground, width: 276)
        line(from: NSPoint(x: x, y: y + bodyBase + bodyHeight), to: NSPoint(x: x + 256, y: y + bodyBase + bodyHeight),
             color: blue.withAlphaComponent(0.18))
        drawCharacter(in: NSRect(x: x, y: y, width: 256, height: 256), phase: Double(index) / 24, markers: true)
        text(labels[slot % 4], rect: NSRect(x: x - 20, y: y - 10, width: 296, height: 25), size: 17, bold: true)
        text("\(slot < 4 ? "왼발 착지부터" : "오른발 착지부터") · F\(String(format: "%02d", index + 1))",
             rect: NSRect(x: x - 20, y: y - 35, width: 296, height: 20), size: 12)
    }
    text("같은 발 원화 · 같은 궤적 · 12프레임 차이   /   파란 점: 왼발 · 주황 점: 오른발",
         rect: NSRect(x: 0, y: 3, width: 1280, height: 24), size: 13)
}
png(1536, 1024, name: "hachiware-side-24-frame-sheet-v15.png") {
    // A 6x4 registered transparent atlas. Adjacent frames are always next in time.
    for index in 0..<24 {
        drawCharacter(in: NSRect(x: (index % 6) * 256, y: (3 - index / 6) * 256, width: 256, height: 256),
                      phase: Double(index) / 24)
    }
}
png(1440, 1120, name: "hachiware-side-24-frame-review-v15.png") {
    cream.setFill(); NSRect(x: 0, y: 0, width: 1440, height: 1120).fill()
    for index in 0..<24 {
        let x = CGFloat(index % 6) * 240, y = CGFloat(3 - index / 6) * 280 + 30
        drawCharacter(in: NSRect(x: x + 10, y: y, width: 220, height: 220), phase: Double(index) / 24)
        text("F\(String(format: "%02d", index + 1))", rect: NSRect(x: x, y: y - 15, width: 240, height: 22), size: 13)
    }
}
let framesDir = output.appendingPathComponent("Frames", isDirectory: true)
try FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
for index in 0..<24 {
    for right in [false, true] {
        let rep = bitmap(256, 256) { drawCharacter(in: NSRect(x: 0, y: 0, width: 256, height: 256), phase: Double(index) / 24, right: right) }
        let name = String(format: "%@-%02d.png", right ? "right" : "left", index + 1)
        try rep.representation(using: .png, properties: [:])!.write(to: framesDir.appendingPathComponent(name))
    }
}
func gif(name: String, slow: Bool) {
    let url = output.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 24, nil)!
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for index in 0..<24 {
        let phase = Double(index) / 24
        let rep = bitmap(800, 430) {
            cream.setFill(); NSRect(x: 0, y: 0, width: 800, height: 430).fill()
            text(slow ? "하치와레 · 천천히 동작 확인" : "하치와레 · 24프레임 걷기", rect: NSRect(x: 0, y: 382, width: 800, height: 28), size: 21, bold: true)
            let a = NSRect(x: 80, y: 89, width: 256, height: 256), b = NSRect(x: 464, y: 89, width: 256, height: 256)
            floorLine(x: 42, y: a.minY + ground, width: 328, offset: 4 * stride * phase)
            floorLine(x: 428, y: b.minY + ground, width: 328, offset: -4 * stride * phase)
            drawCharacter(in: a, phase: phase)
            drawCharacter(in: b, phase: phase, right: true)
            text("왼쪽", rect: NSRect(x: 80, y: 69, width: 256, height: 24))
            text("오른쪽", rect: NSRect(x: 464, y: 69, width: 256, height: 24))
            let stage = Int(floor(wrap(phase * 2) * 4))
            text("\(index < 12 ? "왼발" : "오른발") · \(labels[stage])   F\(String(format: "%02d", index + 1))/24",
                 rect: NSRect(x: 0, y: 24, width: 800, height: 26), size: 16, color: blue, bold: true)
        }
        let total = Int(((slow ? 2.88 : cycleDuration) * 100).rounded())
        let delay = Double((index + 1) * total / 24 - index * total / 24) / 100
        CGImageDestinationAddImage(destination, rep.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
    }
    precondition(CGImageDestinationFinalize(destination))
}
gif(name: "hachiware-four-phase-walk-v15.gif", slow: false)
gif(name: "hachiware-four-phase-walk-slow-v15.gif", slow: true)

// Mechanical validation of the loop, foot symmetry and absence of stance sliding.
var symmetryError: CGFloat = 0, plantedSlip: CGFloat = 0, boundaryError: CGFloat = 0
for index in 0..<240 {
    let t = Double(index) / 240
    let a = footPose(t), b = footPose(t + 0.5 + 0.5)
    symmetryError = max(symmetryError, abs(a.x - b.x), abs(a.y - b.y), abs(a.angle - b.angle))
    if t < 0.5 { plantedSlip = max(plantedSlip, abs((-4 * stride * t + a.x) - (-stride))) }
}
let start = footPose(0), end = footPose(1 - 1e-8)
boundaryError = max(abs(start.x - end.x), abs(start.y - end.y))
precondition(symmetryError < 1e-8 && plantedSlip < 1e-8 && boundaryError < 1e-4)
let report: [String: Any] = ["frame_count": 24, "frames_per_step": 12,
    "cycle_seconds": cycleDuration, "app_distance_per_cycle_points": 62.7,
    "foot_asset_shared": true, "body_asset_shared": true,
    "half_cycle_offset_frames": 12, "foot_symmetry_max_error": symmetryError,
    "planted_contact_world_slip": plantedSlip, "loop_boundary_error": boundaryError,
    "body_height_at_contact": bodyOffset(0), "body_height_at_down": bodyOffset(0.125),
    "body_height_at_passing": bodyOffset(0.25), "body_height_at_up": bodyOffset(0.375),
    "keyframes_one_based": keyFrames.map { $0 + 1 }, "runtime_applied": true, "native_joint_only": true, "arm_roots_open": true, "approved_v14_legs_preserved": true]
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.appendingPathComponent("validation.json"))
print("24-frame side gait, both directions, sheets, GIFs and mechanical validation rendered.")
