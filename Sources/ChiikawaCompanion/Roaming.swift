import AppKit

enum DesktopActivity {
    case walking, idle, hovering, dragging, notifying

    static let updateInterval: TimeInterval = 1.0 / 60

    // Hover is a live input, not a timed reaction: leaving releases it on the next update.
    static func resolve(roaming: Bool, hovered: Bool, dragging: Bool,
                        notificationUntil: Date, now: Date) -> DesktopActivity {
        if now < notificationUntil { return .notifying }
        if hovered { return .hovering }
        if dragging { return .dragging }
        return roaming ? .walking : .idle
    }

    var reacts: Bool { self == .hovering || self == .notifying }
}

enum DesktopLayer {
    // Use WindowServer's current levels, rather than hard-coding their values.
    static var character: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }
    static var bubble: NSWindow.Level { NSWindow.Level(rawValue: character.rawValue + 1) }
    static let collection: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone, .fullScreenDisallowsTiling
    ]
}

/// A complete left/right-foot cycle covers 62.7 desktop points, regardless of elapsed time.
/// Only committed walking displacement advances this phase; dragging and teleports do not.
struct WalkingGait {
    static let distancePerCycle: CGFloat = 62.7
    private(set) var distanceWalked: CGFloat = 0

    var phase: Double { Double(distanceWalked / Self.distancePerCycle) * 2 * .pi }

    mutating func recordMovement(from start: NSPoint, to end: NSPoint) {
        distanceWalked += hypot(end.x - start.x, end.y - start.y)
    }
}

/// Pure movement model: the destination covers the whole usable desktop, in both axes.
struct RoamingMotion {
    static let defaultSpeed: CGFloat = 46
    static var previewCycleDuration: TimeInterval { Double(WalkingGait.distancePerCycle / defaultSpeed) }
    var destination: NSPoint?
    // Keep fractional progress across display updates. Reading a rounded NSWindow origin
    // every frame can otherwise discard slow movement and stall just outside arrival range.
    private(set) var precisePosition: NSPoint?
    var velocity = CGVector.zero
    var facing: CGFloat = 1
    var distanceWalked: CGFloat = 0
    var speed: CGFloat = Self.defaultSpeed

    var isWalking: Bool { hypot(velocity.dx, velocity.dy) > 0.5 }

    mutating func stop() { velocity = .zero; precisePosition = nil }
    mutating func retarget() { destination = nil; stop() }

    static func target(in bounds: NSRect, size: NSSize, xFraction: CGFloat, yFraction: CGFloat) -> NSPoint {
        let width = max(0, bounds.width - size.width)
        let height = max(0, bounds.height - size.height)
        return NSPoint(x: bounds.minX + width * min(1, max(0, xFraction)),
                       y: bounds.minY + height * min(1, max(0, yFraction)))
    }

    mutating func advance(from origin: NSPoint, dt: TimeInterval, bounds: NSRect, size: NSSize) -> NSPoint {
        let current = DesktopGeometry.clamp(precisePosition ?? origin, size: size, to: bounds)
        guard dt > 0, let destination else { stop(); return current }
        let goal = DesktopGeometry.clamp(destination, size: size, to: bounds)
        self.destination = goal
        let dx = goal.x - current.x, dy = goal.y - current.y
        let distance = hypot(dx, dy)
        guard distance > 5 else {
            self.destination = nil; stop(); return current
        }
        let step = CGFloat(min(dt, 0.06))
        let desiredSpeed = min(speed, distance * 2.5)
        let blend = min(1, step * 6)
        velocity.dx += (dx / distance * desiredSpeed - velocity.dx) * blend
        velocity.dy += (dy / distance * desiredSpeed - velocity.dy) * blend
        if abs(velocity.dx) > 1 { facing = velocity.dx > 0 ? 1 : -1 }
        let move = CGVector(dx: velocity.dx * step, dy: velocity.dy * step)
        let position = DesktopGeometry.clamp(NSPoint(x: current.x + move.dx, y: current.y + move.dy),
                                             size: size, to: bounds)
        precisePosition = position
        distanceWalked += hypot(position.x - current.x, position.y - current.y)
        return position
    }
}
