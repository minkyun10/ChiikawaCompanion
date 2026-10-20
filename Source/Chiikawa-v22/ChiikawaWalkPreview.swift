// Review assets only. The installed app changes after the user reviews this sheet.
// Uses the established native rig workflow: image_gen parts + one shared two-foot path.
import AppKit
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

let args = CommandLine.arguments
guard args.count == 4 else { fatalError("Usage: ChiikawaWalkPreview <rig.png> <bold-limbs.png> <output-folder>") }
let output = URL(fileURLWithPath: args[3], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let atlasRep = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: args[1])))!
let atlas = atlasRep.cgImage!
precondition(atlas.width == 1254 && atlas.height == 1254 && atlasRep.hasAlpha)
let ink = NSColor(srgbRed: 0.26, green: 0.13, blue: 0.12, alpha: 1)
let paper = NSColor(srgbRed: 0.98, green: 0.97, blue: 0.95, alpha: 1)
let pink = NSColor(srgbRed: 0.82, green: 0.45, blue: 0.53, alpha: 1)
let frameCount = 24
let cycleDuration = 62.7 / 46.0
let ground: CGFloat = 26
let bodyBase: CGFloat = 44
let bodyHeight: CGFloat = 194
let stride: CGFloat = 62.7 / (4 * (132.0 / 256.0))
let lift: CGFloat = 13
let bob: CGFloat = 4.2

func bitmap(_ w: Int, _ h: Int, _ draw: () -> Void = {}) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32)!
    memset(rep.bitmapData!, 0, rep.bytesPerRow * h)
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    context.imageInterpolation = .high; draw(); context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
func save(_ rep: NSBitmapImageRep, _ name: String) {
    let url = output.appendingPathComponent(name)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}
func picture(_ rep: NSBitmapImageRep) -> NSImage {
    NSImage(cgImage: rep.cgImage!, size: NSSize(width: rep.pixelsWide, height: rep.pixelsHigh))
}
func digest(_ rep: NSBitmapImageRep) -> String {
    SHA256.hash(data: Data(bytes: rep.bitmapData!, count: rep.bytesPerRow * rep.pixelsHigh))
        .map { String(format: "%02x", $0) }.joined()
}
func caption(_ string: String, _ rect: NSRect, size: CGFloat = 16, bold: Bool = false) {
    let style = NSMutableParagraphStyle(); style.alignment = .center
    (string as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size,
        weight: bold ? .semibold : .regular), .foregroundColor: ink, .paragraphStyle: style])
}

// The generated cells use generous gutters, but their artwork is not a perfect grid.
// These explicit source rectangles retain every ear and all original alpha pixels.
let crops: [(String, CGRect)] = [
    ("front-body", CGRect(x: 45, y: 20, width: 385, height: 395)),
    ("side-body", CGRect(x: 445, y: 20, width: 350, height: 395)),
    ("back-body", CGRect(x: 820, y: 20, width: 390, height: 400)),
    ("front-diagonal-body", CGRect(x: 55, y: 425, width: 375, height: 380)),
    ("back-diagonal-body", CGRect(x: 450, y: 425, width: 360, height: 385)),
    ("foot", CGRect(x: 920, y: 530, width: 230, height: 230)),
    ("arm", CGRect(x: 120, y: 910, width: 210, height: 240)),
    ("happy", CGRect(x: 430, y: 810, width: 385, height: 410)),
    ("crying", CGRect(x: 820, y: 810, width: 390, height: 410))
]
var sourceParts: [[String: Any]] = []
func part(_ index: Int) -> NSImage {
    let (name, rect) = crops[index]
    let cg = atlas.cropping(to: rect)!
    let rep = NSBitmapImageRep(cgImage: cg)
    var x0 = cg.width, x1 = 0, y0 = cg.height, y1 = 0
    for y in 0..<cg.height { for x in 0..<cg.width {
        if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.25 {
            x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
        }
    } }
    precondition(x1 > x0 && y1 > y0)
    x0 = max(0, x0 - 2); y0 = max(0, y0 - 2)
    x1 = min(cg.width - 1, x1 + 2); y1 = min(cg.height - 1, y1 + 2)
    let trimmed = cg.cropping(to: CGRect(x: x0, y: y0, width: x1-x0+1, height: y1-y0+1))!
    let image = NSImage(cgImage: trimmed, size: NSSize(width: trimmed.width, height: trimmed.height))
    let normalized = bitmap(trimmed.width, trimmed.height) { image.draw(in: NSRect(origin: .zero, size: image.size)) }
    save(normalized, "Parts/\(name).png")
    sourceParts.append(["name": name, "source_rect_top_left": [rect.minX, rect.minY, rect.width, rect.height],
        "trimmed_pixels": [trimmed.width, trimmed.height]])
    return image
}
let bodies = (0..<5).map(part)
let originalFoot = part(5), originalArm = part(6)
let happy = part(7), crying = part(8)
let boldAtlas = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: args[2])))!.cgImage!
func boldPart(_ index: Int, name: String) -> NSImage {
    let cellWidth = boldAtlas.width / 2
    let cg = boldAtlas.cropping(to: CGRect(x: index*cellWidth, y: 0, width: cellWidth, height: boldAtlas.height))!
    let rep = NSBitmapImageRep(cgImage: cg)
    var x0 = cg.width, x1 = 0, y0 = cg.height, y1 = 0
    for y in 0..<cg.height { for x in 0..<cg.width where (rep.colorAt(x:x,y:y)?.alphaComponent ?? 0)>0.25 {
        x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
    } }
    precondition(x1>x0 && y1>y0)
    x0=max(0,x0-2);y0=max(0,y0-2);x1=min(cg.width-1,x1+2);y1=min(cg.height-1,y1+2)
    let trimmed=cg.cropping(to:CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1))!
    let image=NSImage(cgImage:trimmed,size:NSSize(width:trimmed.width,height:trimmed.height))
    save(bitmap(trimmed.width,trimmed.height) { image.draw(in:NSRect(origin:.zero,size:image.size)) },"Parts/\(name).png")
    sourceParts.append(["name":name,"source":"chiikawa-bold-limb-parts-v2.png",
        "source_rect_top_left":[index*cellWidth+x0,y0,x1-x0+1,y1-y0+1],"trimmed_pixels":[trimmed.width,trimmed.height]])
    return image
}
let foot=boldPart(0,name:"foot-bold"),arm=boldPart(1,name:"arm-bold")

struct Step {
    var x: CGFloat, y: CGFloat, angle: CGFloat
}
func wrap(_ t: Double) -> Double { t - floor(t) }
func footPose(_ phase: Double) -> Step {
    let t = wrap(phase)
    if t < 0.5 {
        return Step(x: -stride + 4 * stride * t, y: ground,
                    angle: CGFloat(-28 + 60 * t / 0.5) * .pi / 180)
    }
    let u = t * 2 - 1
    let h00 = 2*u*u*u - 3*u*u + 1, h10 = u*u*u - 2*u*u + u
    let h01 = -2*u*u*u + 3*u*u, h11 = u*u*u - u*u
    let x: CGFloat = stride * CGFloat(h00 + 2*h10 - h01 + 2*h11)
    let y: CGFloat = ground + lift * CGFloat(pow(sin(Double.pi * u), 2))
    let ease: Double = u * u * (3.0 - 2.0 * u)
    let degrees: Double = 32.0 - 60.0 * ease
    let angle = CGFloat(degrees * Double.pi / 180.0)
    return Step(x: x, y: y, angle: angle)
}
func bodyOffset(_ phase: Double) -> CGFloat { -bob * sin(4 * .pi * phase) }

enum ViewAngle: Int, CaseIterable {
    case front, side, back, frontDiagonal, backDiagonal
    var projection: CGVector {
        switch self {
        case .side: return CGVector(dx: 1, dy: 0)
        case .front: return CGVector(dx: 0, dy: 0.25)
        case .back: return CGVector(dx: 0, dy: -0.25)
        case .frontDiagonal: return CGVector(dx: 0.65, dy: 0.28)
        case .backDiagonal: return CGVector(dx: 0.65, dy: -0.28)
        }
    }
    var footSize: CGSize {
        self == .side ? CGSize(width: 16, height: 26) : CGSize(width: 18, height: 24)
    }
    var roots: [CGFloat] { self == .side ? [0, 0] : [-15, 15] }
    var armRoots: [CGFloat] {
        switch self {
        case .side: return [77, 148]
        case .frontDiagonal, .backDiagonal: return [58, 190]
        default: return [55, 201]
        }
    }
    func leg(_ phase: Double, index: Int) -> Step {
        let p = footPose(phase + Double(index) * 0.5)
        return Step(x: 128 + roots[index] + projection.dx * p.x,
                    y: p.y + projection.dy * p.x,
                    angle: p.angle * (self == .side ? 1 : 0.22))
    }
}
struct Joint { let a: CGPoint; let b: CGPoint; let radius: CGFloat }
func distance(_ q: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x-a.x, dy = b.y-a.y
    let t = min(1, max(0, ((q.x-a.x)*dx + (q.y-a.y)*dy) / max(1, dx*dx+dy*dy)))
    return hypot(q.x-a.x-t*dx, q.y-a.y-t*dy)
}
func connector(_ a: CGPoint, _ b: CGPoint) {
    let p = NSBezierPath(); p.move(to: a); p.line(to: b); p.lineCapStyle = .round
    p.lineWidth = 13; ink.setStroke(); p.stroke()
    p.lineWidth = 8; NSColor.white.setStroke(); p.stroke()
}
func drawFoot(_ p: Step, angle: ViewAngle) {
    let cg = NSGraphicsContext.current!.cgContext
    cg.saveGState(); cg.translateBy(x: p.x, y: p.y + angle.footSize.width/2)
    cg.rotate(by: p.angle)
    foot.draw(in: NSRect(x: -angle.footSize.width/2, y: -angle.footSize.width/2,
                        width: angle.footSize.width, height: angle.footSize.height))
    cg.restoreGState()
}
func drawArm(_ x: CGFloat, _ y: CGFloat, _ rotation: CGFloat) {
    let cg = NSGraphicsContext.current!.cgContext
    cg.saveGState(); cg.translateBy(x: x, y: y); cg.rotate(by: rotation)
    cg.addRect(CGRect(x: -16, y: -31, width: 32, height: 30)); cg.clip()
    arm.draw(in: NSRect(x: -8.5, y: -26, width: 17, height: 31))
    cg.restoreGState()
}
var rawFrames: [ViewAngle: [NSBitmapImageRep]] = [:]
var frames: [ViewAngle: [NSBitmapImageRep]] = [:]
func makeFrame(_ angle: ViewAngle, _ phase: Double) -> NSBitmapImageRep {
    let bodyY = bodyBase + bodyOffset(phase)
    let legs = [angle.leg(phase, index: 0), angle.leg(phase, index: 1)]
    let hips = (0..<2).map { i in CGPoint(x: 128 + angle.roots[i] + (legs[i].x-128-angle.roots[i]) * 0.35,
                                         y: bodyY + 25) }
    let rootPoints = legs.map { p in CGPoint(x: p.x - sin(p.angle) * 15,
                                           y: p.y + angle.footSize.width/2 + cos(p.angle) * 15) }
    var joints = (0..<2).map { Joint(a: rootPoints[$0], b: hips[$0], radius: 8.3) }
    let swing = CGFloat(cos(2 * .pi * phase)) * .pi / 8
    let armY = bodyY + 66
    let body = bodies[angle.rawValue]
    let bodyWidth = body.size.width / body.size.height * bodyHeight
    let bodyRect = NSRect(x:128-bodyWidth/2,y:bodyY,width:bodyWidth,height:bodyHeight)
    joints += angle.armRoots.map { Joint(a: CGPoint(x: $0, y: armY-2),
                                         b: CGPoint(x: $0, y: armY+1), radius: 7) }
    let raw = bitmap(256, 256) {
        if angle == .side { drawArm(angle.armRoots[0], armY, -swing) }
        for i in 0..<2 { connector(rootPoints[i], hips[i]) }
        drawFoot(legs[1], angle: angle)
        body.draw(in: bodyRect)
        drawFoot(legs[0], angle: angle)
        if angle != .side { drawArm(angle.armRoots[0], armY, -swing) }
        drawArm(angle.armRoots[1], armY, swing)
    }
    rawFrames[angle, default: []].append(raw)
    let rep = bitmap(256, 256) { picture(raw).draw(in: NSRect(x: 0, y: 0, width: 256, height: 256)) }
    // Open only internal contours at the leg/shoulder unions. Preserve silhouette pixels.
    let bytes = rep.bitmapData!, row = rep.bytesPerRow
    let alpha = (0..<256*256).map { Int(bytes[($0/256)*row + ($0%256)*4+3]) }
    for py in 115..<241 { for px in 30..<226 {
        let point = CGPoint(x: CGFloat(px)+0.5, y: 255.5-CGFloat(py))
        // The rear tail sits between the legs; it is a feature, not an internal joint seam.
        if angle == .back && hypot(point.x-129,point.y-bodyY-17)<15 { continue }
        guard joints.contains(where: { distance(point, $0.a, $0.b) < $0.radius }) else { continue }
        let offset = py*row+px*4
        guard alpha[py*256+px] > 250 else { continue }
        var interior = true
        for dy in -2...2 { for dx in -2...2 where dx*dx+dy*dy <= 5 {
            if alpha[(py+dy)*256+px+dx] < 240 { interior = false }
        } }
        if interior { bytes[offset]=255; bytes[offset+1]=255; bytes[offset+2]=255 }
    } }
    if angle == .back {
        return bitmap(256,256) {
            picture(rep).draw(in:NSRect(x:0,y:0,width:256,height:256))
            let cg=NSGraphicsContext.current!.cgContext;cg.saveGState()
            cg.addEllipse(in:CGRect(x:114,y:bodyY+2,width:30,height:30));cg.clip()
            body.draw(in:bodyRect);cg.restoreGState()
        }
    }
    return rep
}
func mirror(_ rep: NSBitmapImageRep) -> NSBitmapImageRep {
    let result = bitmap(256, 256)
    for y in 0..<256 { for x in 0..<256 { for c in 0..<4 {
        result.bitmapData![y*result.bytesPerRow+x*4+c] = rep.bitmapData![y*rep.bytesPerRow+(255-x)*4+c]
    } } }
    return result
}
for angle in ViewAngle.allCases {
    frames[angle] = (0..<frameCount).map { makeFrame(angle, Double($0)/Double(frameCount)) }
}
typealias Direction = (slug: String, label: String, angle: ViewAngle, mirrored: Bool)
let directions: [Direction] = [
    ("left", "LEFT", .side, false), ("right", "RIGHT", .side, true),
    ("down", "DOWN", .front, false), ("up", "UP", .back, false),
    ("down-left", "DOWN LEFT", .frontDiagonal, false), ("down-right", "DOWN RIGHT", .frontDiagonal, true),
    ("up-left", "UP LEFT", .backDiagonal, false), ("up-right", "UP RIGHT", .backDiagonal, true)
]
var directionalFrames: [String: [NSBitmapImageRep]] = [:]
func drawFrame(_ rep: NSBitmapImageRep, _ rect: NSRect) { picture(rep).draw(in: rect) }
func atlasImage(_ images: [NSBitmapImageRep]) -> NSBitmapImageRep {
    bitmap(1536, 1024) {
        for i in 0..<24 {
            drawFrame(images[i], NSRect(x: (i%6)*256, y: (3-i/6)*256, width: 256, height: 256))
        }
    }
}
for dir in directions {
    let images = frames[dir.angle]!.map { dir.mirrored ? mirror($0) : $0 }
    directionalFrames[dir.slug] = images
    save(atlasImage(images), "Atlases/chiikawa-\(dir.slug)-24.png")
    for i in 0..<24 { save(images[i], String(format: "Frames/%@-%02d.png", dir.slug, i+1)) }
}
for angle in ViewAngle.allCases { save(atlasImage(rawFrames[angle]!), "Raw/angle-\(angle.rawValue)-before-joint-cleanup.png") }

let keys = [0, 3, 6, 9, 12, 15, 18, 21]
func review(_ selected: [Direction], name: String, title: String) {
    save(bitmap(1600, 940) {
        paper.setFill(); NSRect(x: 0, y: 0, width: 1600, height: 940).fill()
        caption(title, NSRect(x: 0, y: 888, width: 1600, height: 36), size: 24, bold: true)
        caption("24 frames / cycle · identical left-right path · half-cycle offset", NSRect(x: 0, y: 859, width: 1600, height: 24), size: 15)
        for (r, dir) in selected.enumerated() {
            let y = CGFloat(3-r)*202+30
            caption(dir.label, NSRect(x: 0, y: y+76, width: 125, height: 26), size: 14, bold: true)
            for (col, index) in keys.enumerated() {
                let x = CGFloat(col)*181+132
                drawFrame(directionalFrames[dir.slug]![index], NSRect(x: x, y: y+15, width: 170, height: 170))
                caption("\(index+1)", NSRect(x: x, y: y-2, width: 170, height: 20), size: 11)
            }
        }
    }, name)
}
review(Array(directions[0..<4]), name: "chiikawa-cardinal-keyposes-v22.png", title: "CHIIKAWA · CARDINAL WALK")
review(Array(directions[4..<8]), name: "chiikawa-diagonal-keyposes-v22.png", title: "CHIIKAWA · DIAGONAL WALK")
save(bitmap(1024, 660) {
    paper.setFill(); NSRect(x: 0, y: 0, width: 1024, height: 660).fill()
    caption("CHIIKAWA · 8 DIRECTIONS", NSRect(x: 0, y: 615, width: 1024, height: 30), size: 22, bold: true)
    for (i, dir) in directions.enumerated() {
        let x = CGFloat(i%4)*256, y = CGFloat(1-i/4)*282+40
        drawFrame(directionalFrames[dir.slug]![0], NSRect(x: x+12, y: y+30, width: 232, height: 232))
        caption(dir.label, NSRect(x: x, y: y+4, width: 256, height: 23), size: 15, bold: true)
    }
}, "chiikawa-eight-directions-v22.png")
func gif(_ name: String, slow: Bool) {
    let url = output.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 24, nil)!
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for index in 0..<24 {
        let rep = bitmap(1024, 660) {
            paper.setFill(); NSRect(x: 0, y: 0, width: 1024, height: 660).fill()
            caption("CHIIKAWA · 24-FRAME WALK", NSRect(x: 0, y: 618, width: 1024, height: 28), size: 22, bold: true)
            caption(slow ? "SLOW REVIEW · SAME POSES" : "62.7 pt / cycle · 46 pt/s · 1.36 seconds", NSRect(x: 0, y: 591, width: 1024, height: 23), size: 14)
            for (i, dir) in directions.enumerated() {
                let x = CGFloat(i%4)*256, y = CGFloat(1-i/4)*278+20
                drawFrame(directionalFrames[dir.slug]![index], NSRect(x: x+12, y: y+30, width: 232, height: 232))
                caption(dir.label, NSRect(x: x, y: y+4, width: 256, height: 23), size: 14, bold: true)
            }
        }
        // GIF uses centiseconds. Distribute rounding, keeping the whole cycle at 1.36 s.
        let delay = slow ? 0.12 : (Double(Int((Double(index+1)*136/24).rounded())-Int((Double(index)*136/24).rounded()))/100)
        CGImageDestinationAddImage(destination, rep.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
    }
    precondition(CGImageDestinationFinalize(destination))
}
gif("chiikawa-eight-direction-walk-v22.gif", slow: false)
gif("chiikawa-eight-direction-walk-slow-v22.gif", slow: true)

func componentSizes(_ rep: NSBitmapImageRep) -> [Int] {
    let w = rep.pixelsWide, h = rep.pixelsHigh, bytes = rep.bitmapData!
    var seen = [Bool](repeating: false, count: w*h), sizes: [Int] = []
    for start in 0..<w*h where !seen[start] && bytes[(start/w)*rep.bytesPerRow+(start%w)*4+3]>127 {
        var q = [start], i = 0; seen[start] = true
        while i < q.count {
            let p = q[i]; i += 1; let x = p%w, y = p/w
            for (xx,yy) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] where xx>=0 && xx<w && yy>=0 && yy<h {
                let n = yy*w+xx
                if !seen[n] && bytes[yy*rep.bytesPerRow+xx*4+3]>127 { seen[n]=true; q.append(n) }
            }
        }
        sizes.append(q.count)
    }
    return sizes.sorted(by: >)
}
var symmetryError: CGFloat = 0
for index in 0..<24 {
    let t = Double(index)/24
    for angle in ViewAngle.allCases {
        let a = angle.leg(t, index: 1), b = angle.leg(t+0.5, index: 0)
        symmetryError = max(symmetryError, abs((a.x-angle.roots[1])-(b.x-angle.roots[0])), abs(a.y-b.y), abs(a.angle-b.angle))
    }
}
var stanceDrift: CGFloat = 0
for index in 0...12 {
    let t = Double(index)/24
    stanceDrift = max(stanceDrift, abs((footPose(t).x - 4*stride*t) + stride))
}
var perDirection: [[String: Any]] = []
for dir in directions {
    let images = directionalFrames[dir.slug]!
    let components = images.map { componentSizes($0).filter { $0 > 20 } }
    let clearCorners = images.allSatisfy { $0.bitmapData![3] == 0 && $0.bitmapData![255*4+3] == 0 }
    perDirection.append(["direction":dir.slug,"frame_count":images.count,
        "distinct_pixel_frames":Set(images.map(digest)).count,"transparent_corners":clearCorners,
        "largest_component_counts":components.map(\.count),
        "foot_size_constant_both_legs":[dir.angle.footSize.width,dir.angle.footSize.height]])
}
let validation: [String: Any] = ["date":"2026-10-20","runtime_applied":false,
    "frames_per_complete_left_right_cycle":24,"directions":perDirection,
    "left_right_half_cycle_max_error":symmetryError,"side_planted_foot_compensation_error":stanceDrift,
    "cycle_seconds":cycleDuration,"gif_cycle_seconds":1.36,"slow_gif_cycle_seconds":2.88,
    "app_stride_points":62.7,"app_speed_points_per_second":46,
    "all_body_views_from_one_generated_atlas":true,"right_views_mirror_completed_left_frames":true,
    "body_source_is_constant_between_frames":true,"source_parts":sourceParts]
try JSONSerialization.data(withJSONObject: validation, options: [.prettyPrinted,.sortedKeys])
    .write(to: output.appendingPathComponent("validation.json"))
precondition(symmetryError < 0.00001 && stanceDrift < 0.00001)
print("Rendered 8 directions × 24 frames, 8 atlases, two GIFs, key-pose reviews and source parts.")
