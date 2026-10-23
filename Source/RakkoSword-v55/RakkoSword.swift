import AppKit

/// Native line art follows the supplied sword references. The same hilt and
/// brown scabbard are used on the ground, over the cape and during a swing.
enum RakkoSwordArtwork {
    static let ink = NSColor(hex: 0x51382C)
    static let leather = NSColor(hex: 0x927761)

    private static func shape(_ points: [NSPoint], fill: NSColor, width: CGFloat = 2.5) {
        let path = NSBezierPath(); path.move(to: points[0])
        points.dropFirst().forEach { path.line(to: $0) }; path.close()
        fill.setFill(); path.fill(); ink.setStroke()
        path.lineWidth = width; path.lineJoinStyle = .round; path.stroke()
    }
    private static func line(_ points: [NSPoint], color: NSColor = ink, width: CGFloat = 1.8) {
        let path = NSBezierPath(); path.move(to: points[0]); points.dropFirst().forEach { path.line(to: $0) }
        path.lineWidth = width; path.lineCapStyle = .round; color.setStroke(); path.stroke()
    }
    /// Forty by 160, with the scabbard tip at the bottom and grip at the top.
    static func sheathed(in rect: NSRect, swordInside: Bool = true) {
        let c = NSGraphicsContext.current!.cgContext
        c.saveGState(); c.translateBy(x: rect.minX, y: rect.minY); c.scaleBy(x: rect.width/40, y: rect.height/160)
        shape([NSPoint(x:9,y:113),NSPoint(x:31,y:113),NSPoint(x:34,y:23),
               NSPoint(x:23,y:8),NSPoint(x:10,y:17),NSPoint(x:7,y:39)],fill:leather)
        line([NSPoint(x:11,y:103),NSPoint(x:14,y:29),NSPoint(x:23,y:17)],color:NSColor(hex:0xAA927A),width:1.5)
        shape([NSPoint(x:8,y:106),NSPoint(x:32,y:106),NSPoint(x:32,y:115),NSPoint(x:8,y:115)],fill:NSColor(hex:0xE8DFC9),width:2)
        if swordInside {
            shape([NSPoint(x:14,y:121),NSPoint(x:26,y:121),NSPoint(x:26,y:149),NSPoint(x:14,y:149)],fill:NSColor(hex:0xF6F3E6),width:2)
            for y: CGFloat in [126,132,138,144] { line([NSPoint(x:15,y:y+2),NSPoint(x:25,y:y)],width:1.3) }
            shape([NSPoint(x:5,y:115),NSPoint(x:35,y:115),NSPoint(x:35,y:122),NSPoint(x:5,y:122)],fill:NSColor(hex:0xF5F3E8),width:2.3)
            shape([NSPoint(x:10,y:148),NSPoint(x:30,y:148),NSPoint(x:30,y:154),NSPoint(x:10,y:154)],fill:NSColor(hex:0xF5F3E8),width:2)
        }
        c.restoreGState()
    }
    /// The grip is at the origin. The broad, faceted silver blade points left.
    static func blade(grip: NSPoint, angle: CGFloat, scale: CGFloat = 1) {
        let c = NSGraphicsContext.current!.cgContext
        c.saveGState(); c.translateBy(x:grip.x,y:grip.y); c.rotate(by:angle); c.scaleBy(x:scale,y:scale)
        shape([NSPoint(x:-29,y:12),NSPoint(x:-134,y:12),NSPoint(x:-151,y:0),
               NSPoint(x:-134,y:-12),NSPoint(x:-29,y:-12)],fill:NSColor(hex:0xF5F5ED))
        shape([NSPoint(x:-30,y:0),NSPoint(x:-151,y:0),NSPoint(x:-134,y:-12),NSPoint(x:-30,y:-12)],
              fill:NSColor(hex:0xBFC5C2),width:1.2)
        line([NSPoint(x:-134,y:12),NSPoint(x:-134,y:-12)],width:1.2)
        // A small etched face echoes the reference engraving, without changing
        // the character's own fixed forehead scar or facial proportions.
        let etch = NSColor(hex:0xA4AAA4)
        let circle = NSBezierPath(ovalIn:NSRect(x:-57,y:-7,width:13,height:14))
        etch.setStroke(); circle.lineWidth=0.8; circle.stroke()
        for x: CGFloat in [-53,-48] { line([NSPoint(x:x,y:1),NSPoint(x:x,y:-0.5)],color:etch,width:0.9) }
        line([NSPoint(x:-52,y:-3),NSPoint(x:-50,y:-4),NSPoint(x:-48,y:-3)],color:etch,width:0.8)
        shape([NSPoint(x:-23,y:-7),NSPoint(x:13,y:-7),NSPoint(x:13,y:7),NSPoint(x:-23,y:7)],fill:NSColor(hex:0xF1EDDB),width:2)
        for x: CGFloat in [-17,-10,-3,4] { line([NSPoint(x:x,y:6),NSPoint(x:x+2,y:-6)],width:1.3) }
        shape([NSPoint(x:-30,y:-22),NSPoint(x:-23,y:-22),NSPoint(x:-23,y:22),NSPoint(x:-30,y:22)],fill:NSColor(hex:0xF4F3E8),width:2.4)
        shape([NSPoint(x:12,y:-10),NSPoint(x:18,y:-10),NSPoint(x:18,y:10),NSPoint(x:12,y:10)],fill:NSColor(hex:0xF4F3E8),width:2)
        c.restoreGState()
    }
    static func carried(pose: HachiwarePose, facing: CGFloat, phase: Double,
                        destination: NSRect, scale: CGFloat, foreground: Bool) {
        let rear = pose == .back || pose == .backDiagonal
        let c = NSGraphicsContext.current!.cgContext
        c.saveGState(); c.translateBy(x:destination.minX,y:destination.minY); c.scaleBy(x:scale,y:scale)
        if pose.canMirror && facing>0 { c.translateBy(x:256,y:0); c.scaleBy(x:-1,y:1) }
        let side = pose == .side || pose == .frontDiagonal || pose == .backDiagonal
        c.translateBy(x:side ? 184 : rear ? 171 : 54,y:148-4.2*CGFloat(sin(phase*2)))
        c.rotate(by:side || rear ? -0.23 : 0.25)
        if foreground && !rear { c.clip(to:NSRect(x:-24,y:-5,width:48,height:56)) }
        sheathed(in:NSRect(x:-20,y:-118,width:40,height:160))
        c.restoreGState()
    }
}

extension RosterNativeRig {
    func rakkoSwordGesture(left: NSPoint, right: NSPoint, phase: Double) {
        let wave = CGFloat(sin(phase*2 * .pi)), orbit = CGFloat(cos(phase*2 * .pi))
        let hand = NSPoint(x:84+10*orbit,y:112+5*wave)
        let angle: CGFloat = -0.18+wave*0.68
        // The body/cape never rotates or shrinks. Only the gripping arm and
        // broad blade follow this repeatable twelve-frame slash.
        RakkoSwordArtwork.blade(grip:hand,angle:angle,scale:0.96)
        limb(left,hand,width:13)
        paw(root:right,rotation:0.24-wave*0.10,right:true)
        // Match Rakko's small dark paws; do not add a white ring on the handle.
        ink.setFill(); NSBezierPath(ovalIn:NSRect(x:hand.x-6,y:hand.y-6,width:12,height:12)).fill()
    }
}
