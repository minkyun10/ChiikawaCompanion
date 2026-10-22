import AppKit

/// Measure the white character, excluding the colored weapon and its white barbs.
/// All measurements are cached at launch; the live loop only draws existing pixels.
struct AttackBodyMetrics {
    let head: CGRect
    let feet: CGFloat
    let alpha: CGRect
    let size: NSSize

    static func measure(_ image: NSImage) -> Self? {
        guard let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data) else { return nil }
        let w = rep.pixelsWide, h = rep.pixelsHigh
        var white = [Bool](repeating: false,count: w*h), visited = white, opaque = white
        var alpha = CGRect.null
        for y in 0..<h { for x in 0..<w {
            guard let c = rep.colorAt(x: x,y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.25 else { continue }
            opaque[y*w+x] = true
            alpha = alpha.union(CGRect(x: x,y: y,width: 1,height: 1))
            white[y*w+x] = c.alphaComponent > 0.8
                && min(c.redComponent,c.greenComponent,c.blueComponent) > 0.83
                && max(c.redComponent,c.greenComponent,c.blueComponent)-min(c.redComponent,c.greenComponent,c.blueComponent) < 0.11
        } }
        var largest = CGRect.null, count = 0
        for start in 0..<white.count where white[start] && !visited[start] {
            var queue = [start], cursor = 0, bounds = CGRect.null
            visited[start] = true
            while cursor < queue.count {
                let n = queue[cursor]; cursor += 1
                let x = n%w,y = n/w
                bounds = bounds.union(CGRect(x: x,y: y,width: 1,height: 1))
                for (dx,dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
                    let xx = x+dx, yy = y+dy
                    guard xx >= 0 && xx < w && yy >= 0 && yy < h else { continue }
                    let next = yy*w+xx
                    if white[next] && !visited[next] { visited[next] = true; queue.append(next) }
                }
            }
            if queue.count > count { count = queue.count; largest = bounds }
        }
        guard count > 100, !alpha.isNull, largest.width > 10 else { return nil }
        // Use the ink outline at the feet, rather than a thin white toe that can
        // disappear on downsampling. The central 80% excludes the spear's fork
        // intruding at the far left edge of the face in a diagonal thrust.
        var bottom = Int(largest.maxY)-1
        let left = max(0,Int(largest.minX+largest.width*0.10))
        let right = min(w,Int(largest.maxX-largest.width*0.10))
        for y in 0..<h { for x in left..<right where opaque[y*w+x] { bottom = max(bottom,y) } }
        return Self(head: largest, feet: CGFloat(h-bottom-1), alpha: alpha, size: NSSize(width: w,height: h))
    }
}

struct AttackRegistration {
    let reference: AttackBodyMetrics
    let frames: [AttackBodyMetrics]
    init(referenceMetrics: AttackBodyMetrics, frames: [AttackBodyMetrics]) {
        reference = referenceMetrics; self.frames = frames
    }
    init?(images: [NSImage], reference: NSImage?) {
        guard let reference, let body = AttackBodyMetrics.measure(reference) else { return nil }
        let frames = images.compactMap(AttackBodyMetrics.measure)
        guard !frames.isEmpty, frames.count == images.count else { return nil }
        self.reference = body; self.frames = frames
    }
    func destination(frame: Int, in body: NSRect) -> NSRect {
        let source = frames[frame]
        let unit = min(body.width/reference.size.width, body.height/reference.size.height)
        let square = NSRect(x: body.midX-reference.size.width*unit/2,y: body.midY-reference.size.height*unit/2,
                            width: reference.size.width*unit,height: reference.size.height*unit)
        let scale = reference.head.width/source.head.width
        return NSRect(x: square.minX+(reference.head.midX-source.head.midX*scale)*unit,
            y: square.minY+(reference.feet-source.feet*scale)*unit,
            width: source.size.width*scale*unit,height: source.size.height*scale*unit)
    }
    /// Reserve the whole cycle's extent so the viewport never changes size mid-attack.
    func extent(in body: NSRect) -> NSRect {
        frames.indices.reduce(body) { $0.union(destination(frame: $1,in: body)) }.insetBy(dx: -2,dy: -2).integral
    }
}

final class AttackOverlayView: NSView {
    let friend: Friend
    var body = NSRect.zero
    var time: TimeInterval = 0
    init(friend: Friend) {
        self.friend = friend; super.init(frame: .zero)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.cgContext.clear(bounds)
        if friend.isExpansion { RosterSprites.shared(friend).draw(action: .attack, in: body, elapsed: time) }
        else if friend == .chiikawa { _ = ChiikawaAttackSprites.shared.draw(in: body,time: time) }
        else { _ = WeaponAttackSprites.shared.draw(in: body,time: time) }
    }
}

/// A transparent, click-through viewport for the long spear. The actor's panel,
/// world coordinates and physics retain their original 132 × 150 size. Logical
/// armed hover includes its stable artwork silhouette outside those bounds.
final class AttackOverlay {
    let panel: FriendPanel
    let view: AttackOverlayView
    private var lastFrame: Int?
    init(friend: Friend) {
        view = AttackOverlayView(friend: friend)
        panel = FriendPanel(contentRect: .zero,styleMask: [.borderless,.nonactivatingPanel],backing: .buffered,defer: false)
        panel.contentView = view; panel.title = "\(friend.name) 공격 그림"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.isFloatingPanel = false; panel.level = DesktopLayer.character; panel.collectionBehavior = DesktopLayer.collection
        panel.animationBehavior = .none; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
    }
    func update(actor: FriendActor) {
        let active = actor.friend.canUseWeapon && actor.panel.isVisible && actor.view.action == .attack && !actor.view.isDragging
        let registration = actor.friend.isExpansion ? RosterSprites.shared(actor.friend).registration : actor.friend == .chiikawa ? ChiikawaAttackSprites.shared.registration : WeaponAttackSprites.shared.registration
        guard active, let registration else {
            if !actor.panel.isVisible || actor.view.isDragging {
                actor.armedHoverContact = nil; actor.wasHovered = false
            }
            if actor.view.attackUsesOverlay { actor.view.attackUsesOverlay = false; actor.view.needsDisplay = true }
            if panel.isVisible { panel.orderOut(nil) }; lastFrame=nil; return
        }
        let body = actor.panel.frame
        let extent = registration.extent(in: body)
        if panel.frame != extent { panel.setFrame(extent,display: false) }
        let localBody=NSRect(x: body.minX-extent.minX,y: body.minY-extent.minY,width: body.width,height: body.height)
        let geometryChanged=view.body != localBody
        view.body=localBody;view.time=actor.view.actionTime ?? actor.view.time
        let frame=actor.friend == .chiikawa ? ChiikawaAttackSprites.frameIndex(time:view.time) : WeaponAttackSprites.frameIndex(time:view.time)
        let repaint=geometryChanged || lastFrame != frame || !panel.isVisible
        lastFrame=frame
        if !actor.view.attackUsesOverlay { actor.view.attackUsesOverlay = true; actor.view.needsDisplay = true }
        if !panel.isVisible { panel.order(.above,relativeTo: actor.panel.windowNumber) }
        if repaint { view.needsDisplay = true }
    }
}
