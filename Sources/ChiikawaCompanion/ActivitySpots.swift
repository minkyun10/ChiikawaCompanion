import AppKit

enum ActivitySpot: String, CaseIterable, Codable, Identifiable {
    case desk, furball, rice
    var id: String { rawValue }
    var name: String { self == .desk ? "책상" : self == .furball ? "털뭉치" : "밥" }
    var visitTitle: String { "\(name)\(self == .furball ? "로" : "으로") 가기" }
    var symbol: String { self == .desk ? "book" : self == .furball ? "circle.dotted" : "fork.knife" }
    var action: HachiwareAction { self == .desk ? .study : self == .furball ? .vomit : .eat }
    var cooldown: TimeInterval { self == .furball ? 45 : 30 }
}

/// Life props own world coordinates, separately from the character and carried items.
struct ActivitySpotWorld {
    static let triggerRadius: CGFloat = 34
    static let exitRadius: CGFloat = 84
    private(set) var positions: [ActivitySpot: NSPoint] = [:]
    private(set) var enabled = Set<ActivitySpot>()
    private(set) var latched = Set<ActivitySpot>()
    private(set) var availableAfter: [ActivitySpot: Date] = [:]
    var requested: ActivitySpot?

    mutating func configure(enabled newValue: Set<ActivitySpot>, bounds: NSRect) {
        for spot in enabled.subtracting(newValue) {
            positions[spot] = nil; latched.remove(spot); availableAfter[spot] = nil
            if requested == spot { requested = nil }
        }
        for spot in newValue.subtracting(enabled) {
            let fraction: (CGFloat, CGFloat) = spot == .desk ? (0.23, 0.65) : spot == .furball ? (0.53, 0.40) : (0.81, 0.26)
            positions[spot] = ItemWorld.contactPoint(origin: RoamingMotion.target(in: bounds,
                size: NSSize(width: 132, height: 150), xFraction: fraction.0, yFraction: fraction.1))
        }
        enabled = newValue
    }
    mutating func move(_ spot: ActivitySpot, to point: NSPoint, bounds: NSRect) {
        guard positions[spot] != nil else { return }
        positions[spot] = ItemWorld.clamp(point, to: bounds)
    }
    mutating func observe(contact: NSPoint) {
        for spot in latched {
            guard let point = positions[spot] else { latched.remove(spot); continue }
            if hypot(contact.x - point.x, contact.y - point.y) >= Self.exitRadius { latched.remove(spot) }
        }
    }
    func encounter(contact: NSPoint, automatic: Bool, now: Date,
                   excluding dragged: Set<ActivitySpot> = []) -> ActivitySpot? {
        let candidates = requested.map { [$0] } ?? (automatic ? ActivitySpot.allCases : [])
        return candidates.filter { spot in
            guard enabled.contains(spot), let point = positions[spot], !dragged.contains(spot),
                  hypot(contact.x - point.x, contact.y - point.y) <= Self.triggerRadius else { return false }
            return requested == spot || (!latched.contains(spot) && now >= (availableAfter[spot] ?? .distantPast))
        }.min {
            let a = positions[$0]!, b = positions[$1]!
            let da = hypot(contact.x - a.x, contact.y - a.y), db = hypot(contact.x - b.x, contact.y - b.y)
            return da == db ? $0.rawValue < $1.rawValue : da < db
        }
    }
    func nearbySource(for action: HachiwareAction, contact: NSPoint) -> ActivitySpot? {
        ActivitySpot.allCases.first {
            guard $0.action == action, let point = positions[$0] else { return false }
            return hypot(contact.x - point.x, contact.y - point.y) <= Self.triggerRadius
        }
    }
    mutating func consume(_ spot: ActivitySpot, now: Date) {
        latched.insert(spot); availableAfter[spot] = now.addingTimeInterval(spot.cooldown)
        if requested == spot { requested = nil }
    }
}

/// Small native drawings match the existing accessory artwork and its dark rounded lines.
enum ActivitySpotArtwork {
    static let ink = ItemArtwork.ink
    static func shape(_ points: [NSPoint], fill: NSColor, width: CGFloat = 2.3) {
        let path = NSBezierPath(); path.move(to: points[0]); points.dropFirst().forEach { path.line(to: $0) }; path.close()
        fill.setFill(); path.fill(); ink.setStroke(); path.lineWidth = width; path.lineJoinStyle = .round; path.stroke()
    }
    static func line(_ points: [NSPoint], width: CGFloat = 1.8) { ItemArtwork.path(points, width: width, color: ink) }
    static func draw(_ spot: ActivitySpot, in rect: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.minY); cg.scaleBy(x: rect.width / 104, y: rect.height / 100)
        switch spot {
        case .desk:
            shape([NSPoint(x: 12,y: 45),NSPoint(x: 75,y: 36),NSPoint(x: 75,y: 18),NSPoint(x: 12,y: 28)], fill: NSColor(hex: 0xE6BD8D))
            shape([NSPoint(x: 75,y: 36),NSPoint(x: 94,y: 64),NSPoint(x: 94,y: 46),NSPoint(x: 75,y: 18)], fill: NSColor(hex: 0xCFAB80))
            shape([NSPoint(x: 12,y: 45),NSPoint(x: 33,y: 73),NSPoint(x: 94,y: 64),NSPoint(x: 75,y: 36)], fill: NSColor(hex: 0xF2D2A5))
            shape([NSPoint(x: 24,y: 49),NSPoint(x: 39,y: 68),NSPoint(x: 57,y: 62),NSPoint(x: 73,y: 64),NSPoint(x: 59,y: 44),NSPoint(x: 43,y: 46)], fill: NSColor(hex: 0xFFFDF4), width: 1.6)
            line([NSPoint(x: 57,y: 62),NSPoint(x: 43,y: 46)], width: 1.2)
            for y in [53,57,61] { line([NSPoint(x: 36,y: y),NSPoint(x: 44,y: y-2)], width: 1) }
            for y in [50,54,58] { line([NSPoint(x: 54,y: y),NSPoint(x: 61,y: y+1)], width: 1) }
            ItemArtwork.path([NSPoint(x: 77,y: 52),NSPoint(x: 86,y: 66)], width: 4, color: NSColor(hex: 0xC8795E))
            line([NSPoint(x: 77,y: 52),NSPoint(x: 75,y: 49)], width: 2)
            line([NSPoint(x: 21,y: 34),NSPoint(x: 21,y: 38)], width: 1)
            line([NSPoint(x: 25,y: 33),NSPoint(x: 25,y: 37)], width: 1)
        case .furball:
            let points = (0..<32).map { index -> NSPoint in
                let angle = CGFloat(index) / 32 * 2 * .pi
                let radius: CGFloat = index % 2 == 0 ? 23 : 19
                return NSPoint(x: 52 + cos(angle) * radius, y: 41 + sin(angle) * radius * 0.88)
            }
            shape(points, fill: NSColor(hex: 0xD6C7AB), width: 2)
            let curl = NSBezierPath(); curl.move(to: NSPoint(x: 43,y: 41))
            curl.curve(to: NSPoint(x: 58,y: 43), controlPoint1: NSPoint(x: 40,y: 53), controlPoint2: NSPoint(x: 65,y: 53))
            curl.curve(to: NSPoint(x: 48,y: 34), controlPoint1: NSPoint(x: 53,y: 33), controlPoint2: NSPoint(x: 43,y: 43))
            curl.lineWidth = 1.5; curl.lineCapStyle = .round; ink.setStroke(); curl.stroke()
            line([NSPoint(x: 31,y: 34),NSPoint(x: 26,y: 31)], width: 1.2)
            line([NSPoint(x: 70,y: 51),NSPoint(x: 77,y: 55)], width: 1.2)
            line([NSPoint(x: 43,y: 60),NSPoint(x: 41,y: 66)], width: 1.2)
        case .rice:
            let rice = NSBezierPath(); rice.move(to: NSPoint(x: 25,y: 48))
            for index in 0..<7 {
                let x = CGFloat(25 + index * 8)
                rice.curve(to: NSPoint(x: x+8,y: 49), controlPoint1: NSPoint(x: x,y: 62 + (index % 2 == 0 ? 2 : 0)), controlPoint2: NSPoint(x: x+8,y: 62))
            }
            rice.close(); NSColor(hex: 0xFFFDF5).setFill(); rice.fill(); ink.setStroke(); rice.lineWidth = 2; rice.stroke()
            let bowl = NSBezierPath(); bowl.move(to: NSPoint(x: 24,y: 49)); bowl.line(to: NSPoint(x: 81,y: 49))
            bowl.curve(to: NSPoint(x: 52,y: 24), controlPoint1: NSPoint(x: 77,y: 29), controlPoint2: NSPoint(x: 66,y: 24))
            bowl.curve(to: NSPoint(x: 24,y: 49), controlPoint1: NSPoint(x: 36,y: 24), controlPoint2: NSPoint(x: 28,y: 29))
            NSColor(hex: 0xA3C9A2).setFill(); bowl.fill(); ink.setStroke(); bowl.lineWidth = 2.5; bowl.stroke()
            line([NSPoint(x: 43,y: 23),NSPoint(x: 61,y: 23)], width: 3)
            ItemArtwork.path([NSPoint(x: 40,y: 61),NSPoint(x: 83,y: 78)], width: 3, color: NSColor(hex: 0xAD7954))
            ItemArtwork.path([NSPoint(x: 43,y: 58),NSPoint(x: 85,y: 74)], width: 3, color: NSColor(hex: 0xAD7954))
        }
        cg.restoreGState()
    }
}

final class ActivitySpotView: NSView {
    let spot: ActivitySpot
    var hovered = false
    var isDragging = false
    var onSeek: (() -> Void)?
    var onMove: ((NSPoint) -> Void)?
    var onMoveEnd: (() -> Void)?
    private var down = NSPoint.zero, origin = NSPoint.zero
    private var moved = false
    init(spot: ActivitySpot) {
        self.spot = spot; super.init(frame: NSRect(x: 0,y: 0,width: 104,height: 100))
        setAccessibilityElement(true); setAccessibilityRole(.button)
        setAccessibilityLabel("\(spot.name) — 클릭하면 하치와레가 걸어와 \(spot.action.title). 드래그로 옮기기.")
        toolTip = "\(spot.name) · 가까이 가면 \(spot.action.title) · 드래그로 옮기기"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onSeek?(); return true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.08).setFill()
        NSBezierPath(ovalIn: NSRect(x: 23,y: 13,width: 58,height: 5)).fill()
        ActivitySpotArtwork.draw(spot, in: bounds)
        if hovered {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 5,dy: 7), xRadius: 12,yRadius: 12)
            NSColor(hex: 0x7DA6BC,alpha: 0.55).setStroke(); path.lineWidth = 1.5; path.stroke()
        }
    }
    override func mouseDown(with event: NSEvent) {
        down = NSEvent.mouseLocation; origin = window?.frame.origin ?? .zero
        isDragging = true; moved = false
    }
    override func mouseDragged(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation, dx = mouse.x-down.x, dy = mouse.y-down.y
        if abs(dx)+abs(dy)>4 { moved = true }
        onMove?(NSPoint(x: origin.x+dx+52,y: origin.y+dy+18))
    }
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if moved { onMoveEnd?() } else { onSeek?() }
    }
}

final class DesktopActivitySpot {
    let panel: FriendPanel
    let view: ActivitySpotView
    init(spot: ActivitySpot) {
        view = ActivitySpotView(spot: spot)
        panel = FriendPanel(contentRect: view.bounds, styleMask: [.borderless,.nonactivatingPanel], backing: .buffered,defer: false)
        panel.contentView = view; panel.title = "생활 소품 · \(spot.name)"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.isFloatingPanel = false; panel.level = DesktopLayer.character; panel.collectionBehavior = DesktopLayer.collection
        panel.animationBehavior = .none; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false; panel.ignoresMouseEvents = true
    }
    func update(position: NSPoint?, visible: Bool, mouse: NSPoint, behind characterWindow: Int?) {
        guard visible, let position else { panel.orderOut(nil); return }
        let origin = NSPoint(x: position.x-52,y: position.y-18)
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }
        if !panel.isVisible {
            if let characterWindow { panel.order(.below, relativeTo: characterWindow) } else { panel.orderFrontRegardless() }
        }
        let hovered = panel.occlusionState.contains(.visible) && panel.frame.insetBy(dx: 9,dy: 9).contains(mouse)
        panel.ignoresMouseEvents = !hovered && !view.isDragging
        if view.hovered != hovered { view.hovered = hovered; view.needsDisplay = true }
    }
}
