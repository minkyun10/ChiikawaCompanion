import AppKit

enum CharacterScaleGeometry {
    /// The same ground contact is used by movement, props and the doorway.
    static func offset(size: NSSize, scale: CGFloat) -> NSPoint {
        NSPoint(x:size.width*(1-scale)/2,y:ItemWorld.contactOffset.y*(1-scale))
    }
    static func frame(for movement: NSRect, scale: CGFloat) -> NSRect {
        let offset=offset(size:movement.size,scale:scale)
        return NSRect(x:movement.minX+offset.x,y:movement.minY+offset.y,
                      width:movement.width*scale,height:movement.height*scale)
    }
}

extension FriendActor {
    /// A logical footprint keeps desktop journeys and prop coordinates independent
    /// of a character's presentation size. Native window translation still counts
    /// as real movement, including a direct mouse drag.
    var movementFrame: NSRect {
        guard let previous=scaleWindowFrame,let movement=scaleMovementFrame else { return panel.frame }
        return movement.offsetBy(dx:panel.frame.minX-previous.minX,dy:panel.frame.minY-previous.minY)
    }
    var movementScreen: NSScreen? {
        guard presentationScale != 1 else { return panel.screen }
        let contact=ItemWorld.contactPoint(origin:movementFrame.origin)
        return NSScreen.screens.first { $0.frame.contains(contact) } ?? panel.screen
    }
    func setPresentationScale(_ requested: CGFloat) {
        let scale=friend == .hachiware && requested.isFinite ? max(1,requested):1
        guard abs(scale-presentationScale)>0.000001 else { return }
        let movement=movementFrame
        let frame=CharacterScaleGeometry.frame(for:movement,scale:scale)
        presentationScale=scale
        panel.allowsOffscreenExtent=scale>1
        panel.setFrame(frame,display:false)
        view.frame=NSRect(origin:.zero,size:panel.frame.size)
        view.dragFrameOffset=CharacterScaleGeometry.offset(size:movement.size,scale:scale)
        // Preserve the anchor rather than accumulating AppKit's sub-point
        // rounding once per animation tick while the window grows or shrinks.
        scaleMovementFrame=movement;scaleWindowFrame=panel.frame
        view.needsDisplay=true
    }
    func setMovementOrigin(_ origin: NSPoint) {
        guard presentationScale != 1 || scaleMovementFrame != nil else { panel.setFrameOrigin(origin);return }
        let movement=movementFrame, before=panel.frame.origin
        let frame=CharacterScaleGeometry.frame(for:NSRect(origin:origin,size:movement.size),scale:presentationScale)
        panel.setFrameOrigin(frame.origin)
        scaleMovementFrame=movement.offsetBy(dx:panel.frame.minX-before.x,dy:panel.frame.minY-before.y)
        scaleWindowFrame=panel.frame
    }
}
