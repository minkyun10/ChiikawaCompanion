import AppKit

/// Window occlusion notifications lag behind swapping the two transparent drawing
/// windows. Resolve the actual mouse-down target and its current stacking order
/// instead. This also rejects a foreground app covering just the pointer location.
enum DesktopPointerVisibility {
    static func canReach(_ actor: NSWindow, at point: NSPoint) -> Bool {
        guard actor.isVisible, let order = NSWindow.windowNumbers(options: .allApplications) else { return false }
        let numbers = order.map(\.intValue)
        guard let hit = hitWindow(at: point, frontToBack: numbers) else { return false }
        return canReach(actor: actor.windowNumber, hit: hit, frontToBack: numbers)
    }
    static func hitWindow(at point: NSPoint, frontToBack order: [Int]) -> Int? {
        // System input/observation surfaces can be returned by mouse hit-testing
        // while absent from AppKit's active-space window order. Walk below only
        // those unlisted surfaces; every listed app window still blocks hover.
        var below = 0
        for _ in 0..<16 {
            let hit = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: below)
            if hit == 0 || order.contains(hit) { return hit }
            if hit == below { return nil }
            below = hit
        }
        return nil
    }
    static func canReach(actor: Int, hit: Int, frontToBack order: [Int]) -> Bool {
        guard let actorIndex = order.firstIndex(of: actor) else { return false }
        if hit == 0 { return true }
        guard let hitIndex = order.firstIndex(of: hit) else { return false }
        return hitIndex >= actorIndex
    }
}

/// A point-resolution silhouette in the actor's local coordinates. Empty corners
/// stay click-through; a two-point fringe avoids losing antialiased outlines.
struct CharacterPointerMask {
    let rect: NSRect
    private let pixels: [Bool]
    private let width: Int
    private let height: Int

    init(rect: NSRect, draw: () -> Void) {
        self.rect = rect.integral
        width = Int(self.rect.width); height = Int(self.rect.height)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4, bitsPerPixel: 32)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.cgContext.translateBy(x: -self.rect.minX, y: -self.rect.minY)
        draw(); context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
        var mask = [Bool](repeating: false, count: width * height)
        for y in 0..<height { for x in 0..<width where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
            // Bitmap rows count downward; NSWindow coordinates count upward.
            for dy in -2...2 { for dx in -2...2 where dx * dx + dy * dy <= 4 {
                let xx = x + dx, yy = height - 1 - y + dy
                if xx >= 0 && xx < width && yy >= 0 && yy < height { mask[yy * width + xx] = true }
            } }
        } }
        pixels = mask
    }
    func contains(_ point: NSPoint) -> Bool {
        guard rect.contains(point) else { return false }
        let x = Int(floor(point.x - rect.minX)), y = Int(floor(point.y - rect.minY))
        return pixels[y * width + x]
    }
}

/// Masks are built once per friend/direction, then reused. Input does not depend
/// on the current attack frame or on which window painted that frame.
final class ArmedPointerArtwork {
    static let shared = ArmedPointerArtwork()
    static let body = NSRect(x: 0, y: 0, width: 132, height: 150)
    private var walkingMasks: [String: CharacterPointerMask] = [:]
    private var attackMasks: [Friend: CharacterPointerMask] = [:]

    func walking(_ friend: Friend, pose: HachiwarePose, facing: CGFloat) -> CharacterPointerMask {
        let body = NSRect(origin: .zero, size: friend.actorSize)
        let key = "\(friend.rawValue)-\(pose.rawValue)-\(facing < 0)"
        if let mask = walkingMasks[key] { return mask }
        // The normal actor clips equipped artwork to its original panel.
        let mask = CharacterPointerMask(rect: body) {
            let count = friend == .chiikawa || friend.isExpansion ? 24 : pose.frameCount
            for index in 0..<count {
                FriendArtwork.draw(friend, in: body, time: 0, walking: true, facing: facing,
                    walkPhase: (Double(index) + 0.25) / Double(count) * 2 * .pi, pose: pose,
                    equipped: friend == .hachiware ? .sasumata : nil,
                    chiikawaItem: friend == .chiikawa ? .pinkSasumata : nil,
                    rosterVisual: friend.isExpansion ? RosterVisual(equipped: .weapon) : nil)
            }
        }
        walkingMasks[key] = mask; return mask
    }
    func attack(_ friend: Friend) -> CharacterPointerMask {
        if let mask = attackMasks[friend] { return mask }
        let body = NSRect(origin: .zero, size: friend.actorSize)
        let registration = friend.isExpansion ? RosterSprites.shared(friend).registration : friend == .chiikawa ? ChiikawaAttackSprites.shared.registration : WeaponAttackSprites.shared.registration
        let mask = CharacterPointerMask(rect: registration?.extent(in: body) ?? body) {
            for index in 0..<WeaponAttackSprites.frameCount {
                FriendArtwork.draw(friend, in: body, action: .attack, actionTime: (Double(index) + 0.25) * 0.1)
            }
        }
        attackMasks[friend] = mask; return mask
    }
}

extension FriendActor {
    func pointerIsHovering(at point: NSPoint, armed: Bool, canReach: Bool?) -> Bool {
        guard !view.isDragging else { armedHoverContact = nil; return false }
        let body = panel.frame
        let local = NSPoint(x: (point.x - body.minX) * friend.actorSize.width / body.width,
                            y: (point.y - body.minY) * friend.actorSize.height / body.height)
        let entry: CharacterPointerMask?
        let hit: Bool
        if armed {
            let artwork = ArmedPointerArtwork.shared
            if let contact = armedHoverContact {
                entry = contact
                // Keep the entry silhouette and whole attack cycle stable until
                // the pointer leaves. Moving limbs cannot restart the attack.
                hit = contact.contains(local) || artwork.attack(friend).contains(local)
            } else {
                let mask = artwork.walking(friend, pose: view.walking ? view.pose : .front, facing: view.facing)
                entry = mask; hit = mask.contains(local)
            }
        } else {
            entry = nil; hit = DesktopGeometry.hit(point, in: body)
        }
        guard hit && (canReach ?? DesktopPointerVisibility.canReach(panel, at: point)) else {
            armedHoverContact = nil; return false
        }
        armedHoverContact = entry
        return true
    }
}
