import AppKit

enum ChiikawaDirection: String, CaseIterable {
    case down, up, left, right
    case downLeft = "down-left", downRight = "down-right", upLeft = "up-left", upRight = "up-right"
    static func resolve(pose: HachiwarePose, facing: CGFloat) -> Self {
        switch pose {
        case .side: return facing > 0 ? .right : .left
        case .back: return .up
        case .frontDiagonal: return facing > 0 ? .downRight : .downLeft
        case .backDiagonal: return facing > 0 ? .upRight : .upLeft
        default: return .down
        }
    }
}

enum ChiikawaReaction: String, CaseIterable {
    case happy, crying, startled, determined, gentle
    static let greetings: [(String, ChiikawaReaction)] = [
        ("와아…!", .happy), ("에헤헤…", .gentle), ("응…!", .determined), ("으…", .crying), ("앗…!", .startled)
    ]
}

/// Every direction owns a chronological 6 × 4 atlas. No per-frame resizing or
/// Hachiware frame-count assumptions are applied to the reviewed drawings.
final class ChiikawaSprites {
    static let shared = ChiikawaSprites()
    static let frameCount = 24
    private(set) var frames: [ChiikawaDirection: [NSImage]] = [:]
    private(set) var reactions: [ChiikawaReaction: NSImage] = [:]
    var isReady: Bool {
        ChiikawaDirection.allCases.allSatisfy { frames[$0]?.count == Self.frameCount }
            && reactions.count == ChiikawaReaction.allCases.count
    }
    private init() {
        for direction in ChiikawaDirection.allCases {
            guard let url = HachiwareSprites.assetURL(named: "chiikawa-\(direction.rawValue)-24"),
                  let data = try? Data(contentsOf: url), let bitmap = NSBitmapImageRep(data: data),
                  let atlas = bitmap.cgImage, atlas.width == 1536, atlas.height == 1024 else { continue }
            var cycle: [NSImage] = []
            for index in 0..<Self.frameCount {
                guard let frame = atlas.cropping(to: CGRect(x: index % 6 * 256, y: index / 6 * 256, width: 256, height: 256)) else { break }
                cycle.append(NSImage(cgImage: frame, size: NSSize(width: 256, height: 256)))
            }
            frames[direction] = cycle
        }
        for reaction in ChiikawaReaction.allCases {
            let version = reaction == .happy || reaction == .crying ? "v23" : "v26"
            guard let url = HachiwareSprites.assetURL(named: "chiikawa-\(reaction.rawValue)-\(version)"),
                  let source = NSImage(contentsOf: url) else { continue }
            reactions[reaction] = source
        }
    }
    func draw(in rect: NSRect, time: Double, walking: Bool, facing: CGFloat,
              phase: Double, pose: HachiwarePose, reaction: ChiikawaReaction?, equipped: ChiikawaItem?) {
        let shownPose = walking && reaction == nil ? pose : .front
        let direction = ChiikawaDirection.resolve(pose: shownPose, facing: facing)
        let index = walking && reaction == nil ? HachiwareSprites.frameIndex(phase: phase, count: Self.frameCount) : 0
        guard let frame = frames[direction]?[index] else { return }
        let length = min(rect.width, rect.height)
        let bob = walking ? 0 : CGFloat(sin(time * 2)) * length * 0.003
        let destination = NSRect(x: rect.midX - length / 2, y: rect.midY - length / 2 + bob, width: length, height: length)
        let equipmentRect = destination.offsetBy(dx: 0, dy: walking ? -5.5 * sin(Double(index) / 24 * 4 * .pi) * length / 256 : 0)
        if let equipped { ChiikawaItemArtwork.drawEquipped(equipped, in: equipmentRect, pose: shownPose, facing: facing, behind: true) }
        NSGraphicsContext.current?.imageInterpolation = .high
        if let reaction, let image = reactions[reaction] {
            // Alpha cutouts were retained as complete poses; register by the same
            // 214-point height and 26-point foot baseline used in the walk renderer.
            let height = length * 214 / 256
            let width = image.size.width / image.size.height * height
            image.draw(in: NSRect(x: rect.midX - width / 2, y: destination.minY + length * 26 / 256,
                                  width: width, height: height))
        } else { frame.draw(in: destination) }
        if let equipped { ChiikawaItemArtwork.drawEquipped(equipped, in: equipmentRect, pose: shownPose, facing: facing, behind: false) }
    }
}

enum ChiikawaItem: String, CaseIterable, Codable, Identifiable, DesktopProp {
    case pochette, pinkSasumata, houseKey, stuffedToy
    var id: String { rawValue }
    var owner: Friend { .chiikawa }
    var name: String {
        switch self { case .pochette: return "곰 포셰트"; case .pinkSasumata: return "분홍 사스마타"; case .houseKey: return "집 열쇠"; case .stuffedToy: return "소중한 인형" }
    }
    var symbol: String {
        switch self { case .pochette: return "bag"; case .pinkSasumata: return "sparkles"; case .houseKey: return "key"; case .stuffedToy: return "heart" }
    }
    var spawnFraction: (CGFloat, CGFloat) {
        switch self { case .pochette: return (0.58,0.26); case .pinkSasumata: return (0.66,0.78); case .houseKey: return (0.78,0.15); case .stuffedToy: return (0.88,0.40) }
    }
    func draw(in rect: NSRect) { ChiikawaItemArtwork.draw(self, in: rect) }
}

enum ChiikawaItemArtwork {
    static let pink = NSColor(hex: 0xE9A7BC)
    static let ink = NSColor(hex: 0x684A42)
    static func stroke(_ points: [NSPoint], width: CGFloat, color: NSColor) {
        let p = NSBezierPath(); p.move(to: points[0]); points.dropFirst().forEach { p.line(to: $0) }
        p.lineWidth = width; p.lineCapStyle = .round; p.lineJoinStyle = .round; color.setStroke(); p.stroke()
    }
    static func oval(_ rect: NSRect, color: NSColor, line: CGFloat = 4) {
        let p = NSBezierPath(ovalIn: rect); color.setFill(); p.fill()
        if line > 0 { ink.setStroke(); p.lineWidth = line; p.stroke() }
    }
    static func draw(_ item: ChiikawaItem, in rect: NSRect, strap: Bool = true) {
        if item == .houseKey { ChiikawaLifeItemArtwork.drawKey(in: rect); return }
        if item == .stuffedToy { ChiikawaLifeItemArtwork.drawToy(in: rect); return }
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.minY); cg.scaleBy(x: rect.width / 256, y: rect.height / 256)
        if item == .pochette {
            if strap {
                let loop = NSBezierPath(roundedRect: NSRect(x: 68, y: 97, width: 120, height: 124), xRadius: 52, yRadius: 52)
                loop.lineWidth = 12; ink.setStroke(); loop.stroke(); loop.lineWidth = 6; NSColor.white.setStroke(); loop.stroke()
            }
            oval(NSRect(x: 59, y: 147, width: 38, height: 39), color: pink)
            oval(NSRect(x: 159, y: 147, width: 38, height: 39), color: pink)
            let bag = NSBezierPath(roundedRect: NSRect(x: 48, y: 39, width: 160, height: 130), xRadius: 46, yRadius: 46)
            pink.setFill(); bag.fill(); ink.setStroke(); bag.lineWidth = 5; bag.stroke()
            oval(NSRect(x: 85, y: 108, width: 9, height: 11), color: ink, line: 0)
            oval(NSRect(x: 163, y: 108, width: 9, height: 11), color: ink, line: 0)
            stroke([NSPoint(x: 116, y: 91), NSPoint(x: 128, y: 83), NSPoint(x: 140, y: 91)], width: 4, color: ink)
        } else {
            cg.translateBy(x: 128, y: 128); cg.rotate(by: -0.28); cg.translateBy(x: -128, y: -128)
            stroke([NSPoint(x: 128, y: 20), NSPoint(x: 128, y: 178)], width: 17, color: ink)
            stroke([NSPoint(x: 128, y: 20), NSPoint(x: 128, y: 178)], width: 10, color: pink)
            stroke([NSPoint(x: 128, y: 20), NSPoint(x: 128, y: 43)], width: 9, color: .white)
            let fork = NSBezierPath(); fork.move(to: NSPoint(x: 80, y: 227))
            fork.curve(to: NSPoint(x: 176, y: 227), controlPoint1: NSPoint(x: 60, y: 153), controlPoint2: NSPoint(x: 196, y: 153))
            fork.lineCapStyle = .round; fork.lineWidth = 22; ink.setStroke(); fork.stroke(); fork.lineWidth = 13; pink.setStroke(); fork.stroke()
            for point in [NSPoint(x: 87, y: 216), NSPoint(x: 99, y: 191), NSPoint(x: 128, y: 185), NSPoint(x: 157, y: 191), NSPoint(x: 169, y: 216)] {
                oval(NSRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10), color: .white, line: 2)
            }
        }
        cg.restoreGState()
    }
    static func drawEquipped(_ item: ChiikawaItem, in rect: NSRect, pose: HachiwarePose, facing: CGFloat, behind: Bool) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.minY); cg.scaleBy(x: rect.width / 256, y: rect.height / 256)
        if pose.canMirror && facing > 0 { cg.translateBy(x: 256, y: 0); cg.scaleBy(x: -1, y: 1) }
        let back = pose == .back || pose == .backDiagonal, side = pose == .side
        if item == .pinkSasumata {
            if behind == back { draw(item, in: NSRect(x: back ? 165 : 151, y: 17, width: 90, height: 212)) }
        } else if item == .pochette && !behind {
            let strap = [NSPoint(x: 78, y: 118), NSPoint(x: 174, y: 60)]
            stroke(strap, width: 8, color: ink); stroke(strap, width: 4, color: .white)
            if !back { draw(item, in: NSRect(x: side ? 43 : 103, y: 30, width: 90, height: 78), strap: false) }
        } else if !behind && !back {
            draw(item, in: NSRect(x: side ? 58 : 138, y: 43, width: 62, height: 72), strap: false)
        }
        cg.restoreGState()
    }
}
