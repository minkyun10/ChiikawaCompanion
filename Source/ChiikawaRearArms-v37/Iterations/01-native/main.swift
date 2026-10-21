// Native rig revision: only the upper-diagonal hands change; original feet are preserved.
// Uses the established native rig workflow: image_gen parts + one shared two-foot path.
import AppKit
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

enum RoamingMotion { static let previewCycleDuration: Double = 62.7 / 46 }
extension Bundle { static let module = Bundle(path: FileManager.default.currentDirectoryPath + "/build/ChiikawaCompanion.app")! }
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
var revisedRearArms = false
func rearHand(_ bodyY: CGFloat) {
    // The near hand follows Hachiware's short, round open-root silhouette.
    // The far hand remains behind the torso in this rear three-quarter view.
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 65, y: bodyY + 75))
    path.curve(to: NSPoint(x: 56, y: bodyY + 57),
        controlPoint1: NSPoint(x: 58, y: bodyY + 70), controlPoint2: NSPoint(x: 53, y: bodyY + 64))
    path.curve(to: NSPoint(x: 69, y: bodyY + 62),
        controlPoint1: NSPoint(x: 58, y: bodyY + 50), controlPoint2: NSPoint(x: 68, y: bodyY + 52))
    let fill = path.copy() as! NSBezierPath
    fill.line(to: NSPoint(x: 76, y: bodyY + 69)); fill.close()
    NSColor.white.setFill(); fill.fill()
    ink.setStroke(); path.lineWidth = 4.4; path.lineCapStyle = .round; path.lineJoinStyle = .round; path.stroke()
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
    if !(revisedRearArms && angle == .backDiagonal) {
        joints += angle.armRoots.map { Joint(a: CGPoint(x: $0, y: armY-2),
                                             b: CGPoint(x: $0, y: armY+1), radius: 7) }
    }
    let raw = bitmap(256, 256) {
        if angle == .side { drawArm(angle.armRoots[0], armY, -swing) }
        for i in 0..<2 { connector(rootPoints[i], hips[i]) }
        drawFoot(legs[1], angle: angle)
        body.draw(in: bodyRect)
        drawFoot(legs[0], angle: angle)
        if revisedRearArms && angle == .backDiagonal { rearHand(bodyY) }
        else {
            if angle != .side { drawArm(angle.armRoots[0], armY, -swing) }
            drawArm(angle.armRoots[1], armY, swing)
        }
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

let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let references = project.appendingPathComponent("Source/ChiikawaRearArms-v37/References")
let leftAtlas = NSBitmapImageRep(data: try Data(contentsOf: references.appendingPathComponent("chiikawa-up-left-24.png")))!
let rightAtlas = NSBitmapImageRep(data: try Data(contentsOf: references.appendingPathComponent("chiikawa-up-right-24.png")))!
precondition(!leftAtlas.isPlanar && leftAtlas.samplesPerPixel == 4 && leftAtlas.bitsPerSample == 8)
precondition(leftAtlas.bitmapFormat == rightAtlas.bitmapFormat)
func frame(_ atlas: NSBitmapImageRep, _ index: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: atlas.colorSpaceName,
        bitmapFormat: atlas.bitmapFormat, bytesPerRow: 1024, bitsPerPixel: 32)!
    for y in 0..<256 {
        memcpy(rep.bitmapData! + y * 1024, atlas.bitmapData! + (index / 6 * 256 + y) * atlas.bytesPerRow + index % 6 * 1024, 1024)
    }
    return rep
}
var before: [NSBitmapImageRep] = [], after: [NSBitmapImageRep] = [], right: [NSBitmapImageRep] = []
var records: [[String: Any]] = []
for index in 0..<24 {
    let phase = Double(index) / 24, bodyY = bodyBase + bodyOffset(phase)
    revisedRearArms = false; let originalRig = makeFrame(.backDiagonal, phase)
    revisedRearArms = true; let newRig = makeFrame(.backDiagonal, phase)
    before.append(frame(leftAtlas, index))
    var count = 0, changed = CGRect.null
    for y in 0..<256 { for x in 0..<256 {
        let old = originalRig.bitmapData! + y * originalRig.bytesPerRow + x * 4
        let new = newRig.bitmapData! + y * newRig.bytesPerRow + x * 4
        guard (0..<4).contains(where: { old[$0] != new[$0] }) else { continue }
        let point = NSPoint(x: CGFloat(x) + 0.5, y: 255.5 - CGFloat(y))
        precondition(point.y > 75 && point.y < 140, "Hand edits reached feet or head")
        precondition((34...85).contains(point.x) || (172...215).contains(point.x), "Hand edits reached central torso")
        let color = newRig.colorAt(x: x, y: y)!
        leftAtlas.setColor(color, atX: index % 6 * 256 + x, y: index / 6 * 256 + y)
        rightAtlas.setColor(color, atX: index % 6 * 256 + 255 - x, y: index / 6 * 256 + y)
        count += 1; changed = changed.union(CGRect(x: x, y: y, width: 1, height: 1))
    } }
    after.append(frame(leftAtlas, index)); right.append(frame(rightAtlas, index))
    records.append(["frame": index + 1, "changed_pixels": count,
        "bounds_top_left": [changed.minX,changed.minY,changed.width,changed.height]])
}
save(leftAtlas, "Atlases/chiikawa-up-left-24.png"); save(rightAtlas, "Atlases/chiikawa-up-right-24.png")
for i in 0..<24 {
    save(after[i], String(format: "Frames/up-left-%02d.png", i+1))
    save(right[i], String(format: "Frames/up-right-%02d.png", i+1))
}
func board(_ index: Int) -> NSBitmapImageRep {
    bitmap(840, 630) {
        paper.setFill(); NSRect(x: 0,y: 0,width: 840,height: 630).fill()
        caption("UPPER DIAGONAL · HANDS", NSRect(x: 0,y: 590,width: 840,height: 28), size: 21, bold: true)
        for (col,label) in ["HACHIWARE REFERENCE","BEFORE","AFTER"].enumerated() {
            caption(label, NSRect(x: col*280,y: 550,width: 280,height: 24), size: 13, bold: true)
            for row in 0..<2 {
                let rect = NSRect(x: col*280+24,y: (1-row)*250+50,width: 232,height: 232)
                if col == 0 {
                    HachiwareSprites.shared.draw(in: rect,time: 0,happy: false,walking: true,facing: row == 0 ? -1 : 1,
                        walkPhase: Double(index)/24 * 2 * .pi,pose: .backDiagonal)
                } else {
                    let image = col == 1 ? before[index] : after[index]
                    let context = NSGraphicsContext.current!.cgContext
                    context.saveGState()
                    if row == 1 { context.translateBy(x: rect.midX*2,y: 0);context.scaleBy(x: -1,y: 1) }
                    picture(image).draw(in: rect); context.restoreGState()
                }
            }
        }
        caption("UP LEFT / UP RIGHT · existing 24-frame feet preserved", NSRect(x: 0,y: 15,width: 840,height: 24),size: 14)
    }
}
save(board(0), "hand-comparison-v37.png")
for (name,slow) in [("hand-comparison-v37.gif",false),("hand-comparison-slow-v37.gif",true)] {
    let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL, UTType.gif.identifier as CFString,24,nil)!
    CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
    for index in 0..<24 {
        let delay = slow ? 0.12 : Double(Int((Double(index+1)*136/24).rounded())-Int((Double(index)*136/24).rounded()))/100
        CGImageDestinationAddImage(destination,board(index).cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:delay]] as CFDictionary)
    }
    precondition(CGImageDestinationFinalize(destination))
}
try JSONSerialization.data(withJSONObject: ["frames":records,"protected_local_y_below":75,"protected_local_y_above":140,
    "foot_cycle":24,"rendered_speed_unchanged":true] as [String:Any],options:[.prettyPrinted,.sortedKeys])
    .write(to:output.appendingPathComponent("hand-edit-regions.json"))
print("Rendered upper-diagonal short attached hands; 48 frames and comparison previews.")
