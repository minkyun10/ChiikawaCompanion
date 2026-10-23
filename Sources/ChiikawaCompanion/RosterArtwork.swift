import AppKit

/// Source anatomy comes from the reviewed imagegen rig. All in-betweens use one
/// deterministic native skeleton, shared foot paths and a half-cycle offset.
final class RosterNativeRig {
    let friend: Friend
    let bodies: [HachiwarePose: NSImage]
    let rightBodies: [HachiwarePose: NSImage]
    let arm: NSImage
    let foot: NSImage
    let tail: NSImage?
    let expressions: [RosterAction: NSImage]
    let usagiFace: UsagiFace?
    let newFace: NewFriendFace?
    lazy var sleepingArtwork = RosterSleepArtwork(friend: friend)
    let paper: NSColor
    let ink = NSColor(hex: 0x3A3025)
    var height: CGFloat { friend == .usagi ? 270 : 194 }
    var canvas: NSSize { friend.canvasSize }
    var mouthFraction: CGFloat { friend == .usagi ? 0.35 : friend == .momonga ? 0.43 : 0.47 }
    init?(friend: Friend) {
        func load(_ name: String) -> NSImage? {
            HachiwareSprites.assetURL(named: "\(friend.rawValue)-rig-\(name)-v38").flatMap(NSImage.init(contentsOf:))
        }
        var bodies: [HachiwarePose: NSImage] = [:]
        for (pose, name) in [(HachiwarePose.front,"front"),(.side,"side"),(.back,"back"),(.frontDiagonal,"front-diagonal"),(.backDiagonal,"back-diagonal")] {
            guard let image = load(name) else { return nil }; bodies[pose] = image
        }
        guard let arm = load("arm"), let foot = load("foot") else { return nil }
        var rightBodies: [HachiwarePose: NSImage] = [:]
        if friend == .rakko {
            for (pose,name) in [(HachiwarePose.side,"side"),(.frontDiagonal,"front-diagonal"),(.backDiagonal,"back-diagonal")] {
                guard let image=load(name+"-right") else { return nil }
                rightBodies[pose]=image
            }
        }
        self.rightBodies=rightBodies
        var expressions: [RosterAction: NSImage] = [:]
        for action in [RosterAction.laugh,.attack,.surprised,.sleep] where friend != .usagi && !friend.usesNewFriendRig && RosterAction.available(for: friend).contains(action) {
            if let image = HachiwareSprites.assetURL(named: "\(friend.rawValue)-expression-\(action.rawValue)-v38").flatMap(NSImage.init(contentsOf:)) { expressions[action] = image }
        }
        self.tail = friend == .momonga ? load("tail") : nil
        self.expressions = expressions
        let usagiFace = friend == .usagi ? UsagiFace(body: bodies[.front]!) : nil
        if friend == .usagi && usagiFace == nil { return nil }
        self.usagiFace = usagiFace
        self.newFace = NewFriendFace(friend: friend, body: bodies[.front]!)
        self.friend = friend; self.bodies = bodies; self.arm = arm; self.foot = foot
        if let data = bodies[.front]!.tiffRepresentation, let rep = NSBitmapImageRep(data: data),
           let color = rep.colorAt(x: Int(Double(rep.pixelsWide)*0.48), y: Int(Double(rep.pixelsHigh)*0.82)),
           color.redComponent > 0.7, color.greenComponent > 0.6 {
            // Match the raster's numeric channels in our device-RGB sprite target.
            // Converting the decoded bitmap to display RGB first brightens limb seams.
            paper = NSColor(deviceRed: color.redComponent,green: color.greenComponent,blue: color.blueComponent,alpha: 1)
        }
        else { paper = NSColor(hex: friend == .usagi ? 0xFFF1C6 : friend == .kurimanju ? 0xFFF1DB : 0xFFFDF8) }
    }
    static func bitmap(_ size: NSSize, draw: () -> Void) -> NSBitmapImageRep {
        let w = Int(size.width), h = Int(size.height)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: w,pixelsHigh: h,bitsPerSample: 8,
            samplesPerPixel: 4,hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: w*4,bitsPerPixel: 32)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(origin: .zero,size: size)); context.imageInterpolation = .high
        draw(); context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
        return rep
    }
    func bodyRect(_ pose: HachiwarePose, y: CGFloat) -> NSRect {
        let image = bodies[pose] ?? bodies[.front]!
        let width = image.size.width/image.size.height*height
        return NSRect(x: 128-width/2,y: y,width: width,height: height)
    }
    func root(_ pose: HachiwarePose, y: CGFloat, right: Bool) -> NSPoint {
        let image = bodies[pose] ?? bodies[.front]!, rect = bodyRect(pose,y: y)
        guard let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data) else {
            return NSPoint(x: right ? rect.maxX-8 : rect.minX+8,y: y+70)
        }
        let row = min(rep.pixelsHigh-1,max(0,Int((1-72/height)*CGFloat(rep.pixelsHigh))))
        let xs = (0..<rep.pixelsWide).filter {
            guard let color=rep.colorAt(x:$0,y:row), color.alphaComponent>0.5 else { return false }
            // Shisa's orange mane and tail are in the same raster, but are not arm roots.
            return friend != .shisa || (color.redComponent>0.9 && color.greenComponent>0.75 && color.blueComponent>0.5)
        }
        let edge = right ? xs.last ?? rep.pixelsWide-1 : xs.first ?? 0
        return NSPoint(x: rect.minX+CGFloat(edge)/CGFloat(rep.pixelsWide)*rect.width+(right ? -4 : 4),y: y+72)
    }
    func stroke(_ points: [NSPoint], width: CGFloat, color: NSColor) {
        let path = NSBezierPath(); path.move(to: points[0]); points.dropFirst().forEach { path.line(to: $0) }
        path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round; color.setStroke(); path.stroke()
    }
    func limbPath(_ start: NSPoint, _ end: NSPoint) -> NSBezierPath {
        let path = NSBezierPath(); path.move(to: start)
        path.curve(to: end, controlPoint1: NSPoint(x: start.x+(end.x-start.x)*0.25,y: start.y-8),
                   controlPoint2: NSPoint(x: start.x+(end.x-start.x)*0.72,y: end.y-5))
        path.lineCapStyle = .round
        return path
    }
    func limb(_ start: NSPoint, _ end: NSPoint, width: CGFloat = 13) {
        let path=limbPath(start,end);path.lineWidth=width;ink.setStroke();path.stroke()
        path.lineWidth=width-5;paper.setStroke();path.stroke()
        paper.setFill();NSBezierPath(ovalIn:NSRect(x:start.x-width*0.47,y:start.y-width*0.47,width:width*0.94,height:width*0.94)).fill()
    }
    func paw(root: NSPoint, rotation: CGFloat, right: Bool) {
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState(); context.translateBy(x: root.x,y: root.y); context.rotate(by: rotation)
        if right { context.scaleBy(x: -1,y: 1) }
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 2,y: 2))
        path.curve(to: NSPoint(x: -6,y: -13),controlPoint1: NSPoint(x: -4,y: -1),controlPoint2: NSPoint(x: -9,y: -8))
        path.curve(to: NSPoint(x: 6,y: -9),controlPoint1: NSPoint(x: -4,y: -20),controlPoint2: NSPoint(x: 5,y: -18))
        let fill = path.copy() as! NSBezierPath; fill.line(to: NSPoint(x: 10,y: 3)); fill.close()
        paper.setFill(); fill.fill(); ink.setStroke(); path.lineWidth = 4.2; path.lineCapStyle = .round; path.stroke()
        context.restoreGState()
    }
    func drawFoot(x: CGFloat, y: CGFloat, angle: CGFloat = 0) {
        let context=NSGraphicsContext.current!.cgContext
        context.saveGState();context.translateBy(x:x,y:y+9);context.rotate(by:angle)
        let path=NSBezierPath();path.move(to:NSPoint(x:-7,y:0))
        path.curve(to:NSPoint(x:-8,y:-4),controlPoint1:NSPoint(x:-9,y:0),controlPoint2:NSPoint(x:-10,y:0))
        path.curve(to:NSPoint(x:8,y:-4),controlPoint1:NSPoint(x:-7,y:-14),controlPoint2:NSPoint(x:7,y:-14))
        path.curve(to:NSPoint(x:7,y:0),controlPoint1:NSPoint(x:10,y:0),controlPoint2:NSPoint(x:9,y:0))
        let fill=path.copy() as! NSBezierPath;fill.close();paper.setFill();fill.fill()
        ink.setStroke();path.lineWidth=3.2;path.lineCapStyle = .round;path.stroke();context.restoreGState()
    }
    func drawTail(_ pose: HachiwarePose, y: CGFloat, phase: Double) {
        guard let tail else { return }
        let rear = pose == .back || pose == .backDiagonal
        let rect = NSRect(x: rear ? (pose == .back ? 105 : 124) : 128,
                          y: y+(rear ? 7 : 20),width: rear ? 91 : 110,height: rear ? 157 : 138)
        // The detached source attachment root is outside the visible tail surface.
        tail.draw(in: rect,from: NSRect(x:0,y:tail.size.height*0.08,width:tail.size.width,height:tail.size.height*0.92),operation:.sourceOver,fraction:1)
    }
    func drawBody(_ action: RosterAction, y: CGFloat, phase: Double) {
        drawTail(.front,y:y,phase:phase)
        if let newFace {
            let rect=bodyRect(.front,y:y)
            bodies[.front]!.draw(in:rect);newFace.draw(action,phase:phase,in:rect)
            return
        }

        if let usagiFace {
            let rect = bodyRect(.front, y: y)
            bodies[.front]!.draw(in: rect)
            usagiFace.draw(action, phase: phase, in: rect)
            return
        }

        let expression = action == .wake ? RosterAction.laugh : action
        if let image=expressions[expression] { image.draw(in:bodyRect(.front,y:y)) }
        else { bodies[.front]!.draw(in:bodyRect(.front,y:y)); face(action,y:y,phase:phase) }
    }
    func footPose(_ phase: Double) -> (CGFloat, CGFloat, CGFloat) {
        let t = phase-floor(phase), stride: CGFloat = 62.7/(4*(132.0/256.0))
        if t < 0.5 { return (-stride+4*stride*CGFloat(t),37,CGFloat(-28+120*t) * .pi/180) }
        let u = t*2-1, ease = u*u*(3-2*u)
        let h00 = 2*u*u*u-3*u*u+1, h10 = u*u*u-2*u*u+u, h01 = -2*u*u*u+3*u*u, h11 = u*u*u-u*u
        return (stride*CGFloat(h00+2*h10-h01+2*h11),37+13*CGFloat(pow(sin(.pi*u),2)),CGFloat(32-60*ease) * .pi/180)
    }
    func walk(_ pose: HachiwarePose, phase: Double, rightFacing: Bool = false) -> NSBitmapImageRep {
        let y = 44-4.2*CGFloat(sin(4 * .pi*phase)), rect = bodyRect(pose,y: y)
        let projection: CGVector = pose == .side ? CGVector(dx: 1,dy: 0)
            : pose == .front ? CGVector(dx: 0,dy: 0.25) : pose == .back ? CGVector(dx: 0,dy: -0.25)
            : CGVector(dx: 0.65,dy: pose == .frontDiagonal ? 0.28 : -0.28)
        return Self.bitmap(canvas) {
            var joins:[NSBezierPath]=[]
            for index in [1,0] {
                let p=footPose(phase+Double(index)*0.5), rootX:CGFloat=pose == .side ? 0 : index == 0 ? -15:15
                let x=128+rootX+projection.dx*p.0, yy=p.1+projection.dy*p.0
                let hip=NSPoint(x:128+rootX+(x-128-rootX)*0.35,y:y+20), ankle=NSPoint(x:x,y:yy+9)
                limb(hip,ankle,width:12);drawFoot(x:x,y:yy,angle:p.2*(pose == .side ? 1:0.22));joins.append(limbPath(hip,ankle))
            }
            if pose != .back && pose != .backDiagonal { drawTail(pose,y:y,phase:phase) }
            if rightFacing, let image=rightBodies[pose] {
                // Pre-flip only the asymmetric artwork; the completed gait is mirrored below.
                let context=NSGraphicsContext.current!.cgContext
                context.saveGState();context.translateBy(x:rect.minX+rect.maxX,y:0);context.scaleBy(x:-1,y:1)
                image.draw(in:rect);context.restoreGState()
            } else { bodies[pose]!.draw(in:rect) }
            if pose == .back || pose == .backDiagonal { drawTail(pose,y:y,phase:phase) }
            let context=NSGraphicsContext.current!.cgContext
            context.saveGState()
            if friend == .rakko { context.clip(to:NSRect(x:0,y:0,width:canvas.width,height:y+2)) }
            for join in joins {join.lineWidth=7;paper.setStroke();join.stroke()}
            context.restoreGState()
            let swing = CGFloat(cos(2 * .pi*phase))*0.10
            let near = root(pose,y: y,right: false), far = root(pose,y: y,right: true)
            if pose != .backDiagonal && !(friend.usesNewFriendRig && pose == .side) { paw(root: far,rotation: -swing,right: true) }
            paw(root: near,rotation: swing,right: false)
        }
    }
    func face(_ action: RosterAction, y: CGFloat, phase: Double) {
        let eyesY = y+height*(friend == .usagi ? 0.48 : 0.63), mouthY = y+height*mouthFraction
        if action == .laugh || action == .sleep || action == .wake {
            for x: CGFloat in [101,155] {
                paper.setFill(); NSBezierPath(ovalIn: NSRect(x: x-13,y: eyesY-13,width: 26,height: 26)).fill()
                let eye = NSBezierPath(); eye.move(to: NSPoint(x: x-8,y: eyesY))
                eye.curve(to: NSPoint(x: x+8,y: eyesY),controlPoint1: NSPoint(x: x-4,y: eyesY+(action == .sleep ? -4 : 7)),controlPoint2: NSPoint(x: x+4,y: eyesY+(action == .sleep ? -4 : 7)))
                ink.setStroke(); eye.lineWidth = 3.2; eye.lineCapStyle = .round; eye.stroke()
            }
        }
        if action == .attack {
            let browY = eyesY+19
            for x: CGFloat in [101,155] {
                paper.setFill(); NSBezierPath(ovalIn: NSRect(x: x-19,y: browY-4,width: 38,height: 28)).fill()
                stroke([NSPoint(x: x-9,y: browY+(x<128 ? 8 : 0)),NSPoint(x: x+9,y: browY+(x<128 ? 0 : 8))],width: 3.8,color: ink)
            }
            stroke([NSPoint(x: 123,y: eyesY+12),NSPoint(x: 126,y: eyesY+7)],width: 2,color: ink)
            stroke([NSPoint(x: 132,y: eyesY+12),NSPoint(x: 130,y: eyesY+7)],width: 2,color: ink)
        }
        if action == .attack || action == .surprised {
            paper.setFill(); NSBezierPath(ovalIn: NSRect(x: 113,y: mouthY-17,width: 30,height: 33)).fill()
            ink.setFill(); NSBezierPath(ovalIn: NSRect(x: 119,y: mouthY-10,width: 18,height: action == .surprised ? 20 : 22)).fill()
            if action != .surprised {
                NSColor(hex: 0xEC9AA8).setFill(); NSBezierPath(roundedRect: NSRect(x: 123,y: mouthY-12,width: 11,height: 12),xRadius: 5,yRadius: 5).fill()
            }
        }
    }
    func action(_ action: RosterAction, phase: Double) -> NSBitmapImageRep {
        let size = action == .attack ? NSSize(width: 440,height: canvas.height) : action == .sleep ? RosterSleepArtwork.canvas : canvas
        return Self.bitmap(size) {
            guard RosterAction.available(for: friend).contains(action) else { return }
            let context = NSGraphicsContext.current!.cgContext
            if action == .attack { context.translateBy(x: 120,y: 0) }
            if action == .sleep {
                sleepingArtwork?.draw(phase: phase)
                return
            }
            let y: CGFloat = 44+(action == .pickup ? -8*CGFloat(sin(.pi*phase)) : action == .wake ? 4*CGFloat(sin(.pi*phase)) : 0)
            for x: CGFloat in [113,143] { drawFoot(x:x,y:37) }
            if friend == .rakko && action == .attack {
                context.saveGState(); context.translateBy(x:201,y:144); context.rotate(by:-0.16)
                RakkoSwordArtwork.sheathed(in:NSRect(x:-14,y:-108,width:28,height:132),swordInside:false)
                context.restoreGState()
            }
            drawBody(action,y:y,phase:phase)
            let left = root(.front,y: y,right: false), right = root(.front,y: y,right: true)
            let wave = CGFloat(sin(2 * .pi*phase))
            if friend.usesNewFriendRig {
                drawNewFriendGesture(action,left:left,right:right,wave:wave,phase:phase)
                return
            }
            if friend == .usagi {
                drawUsagiGesture(action, left: left, right: right, wave: wave, phase: phase)
                return
            }
            switch action {
            case .wave, .wake:
                limb(left,NSPoint(x: left.x-7,y: left.y+30+wave*8)); limb(right,NSPoint(x: right.x+6,y: right.y+(action == .wake ? 30 : -13)))
            case .laugh, .surprised:
                limb(left,NSPoint(x: left.x-7,y: left.y+10+abs(wave)*7));limb(right,NSPoint(x: right.x+7,y: right.y+10+abs(wave)*7))
            case .pickup:
                let rise=CGFloat(phase*phase*(3-2*phase))*40
                limb(left,NSPoint(x:95,y:48+rise));limb(right,NSPoint(x:157,y:47+rise))
            case .attack:
                let thrust = CGFloat(sin(2 * .pi*phase))*25
                context.saveGState(); context.translateBy(x: 120+thrust,y: 74);context.rotate(by: -0.10+wave*0.13)
                RosterItemArtwork.weapon(friend: friend,in: NSRect(x: -200,y: -8,width: 330,height: 32));context.restoreGState()
                limb(left,NSPoint(x: 82+thrust,y: 77));limb(right,NSPoint(x: 165+thrust,y: 84))
            case .keepsake:
                if friend == .momonga {
                    RosterItemArtwork.flower(in: NSRect(x: 157,y: 129+wave*5,width: 55,height: 55))
                    limb(left,NSPoint(x: 103,y: 109));limb(right,NSPoint(x: 175,y: 138+wave*5))
                } else if friend == .kurimanju {
                    let sip = phase < 0.72 ? CGFloat(sin(.pi*phase/0.72)) : 0
                    RosterItemArtwork.cup(in: NSRect(x: 99+6*sip,y: 62+18*sip,width: 46,height: 62))
                    RosterItemArtwork.snack(in: NSRect(x: 141,y: 58,width: 55,height: 50))
                    limb(left,NSPoint(x: 116+6*sip,y: 82+18*sip));limb(right,NSPoint(x: 160,y: 80))
                } else {
                    RosterItemArtwork.draw(.keepsake,friend: friend,in: NSRect(x: 94,y: 62+wave*5,width: 68,height: 68))
                    limb(left,NSPoint(x: 106,y: 92));limb(right,NSPoint(x: 151,y: 92+wave*5))
                }
            case .sleep: break
            }
        }
    }

    private func drawNewFriendGesture(_ action: RosterAction, left: NSPoint, right: NSPoint,
                                      wave: CGFloat, phase: Double) {
        if friend == .rakko && action == .attack {
            rakkoSwordGesture(left:left,right:right,phase:phase)
            return
        }
        guard action == .keepsake else {
            let lift: CGFloat = action == .wave ? 1.5 : action == .laugh || action == .wake ? 0.9 : 0.2
            paw(root:left,rotation:-lift+wave*0.18,right:false)
            paw(root:right,rotation:action == .wave ? 0.05:lift-wave*0.18,right:true)
            return
        }
        switch friend {
        case .rakko:
            let scoop=CGFloat(max(0,sin(2 * .pi*phase)))
            let cup=NSRect(x:137,y:61,width:47,height:76)
            RosterItemArtwork.draw(.keepsake,friend:friend,in:cup)
            let mouthRect=newFace!.destination(newFace!.areas[0],in:bodyRect(.front,y:44))
            let mouth=NSPoint(x:mouthRect.midX,y:mouthRect.midY)
            let tip=NSPoint(x:143+(mouth.x-143)*scoop,y:113+(mouth.y-113)*scoop)
            let handle=NSPoint(x:tip.x-13,y:tip.y-25)
            stroke([handle,tip],width:3,color:NSColor(hex:0x8F8582))
            NSColor(hex:0xFFF2D6).setFill();let spoon=NSBezierPath(ovalIn:NSRect(x:tip.x-5,y:tip.y-3,width:10,height:7));spoon.fill();ink.setStroke();spoon.lineWidth=1.7;spoon.stroke()
            limb(left,handle,width:13);limb(right,NSPoint(x:167,y:97),width:13)
        case .shisa:
            // Present the bowl forward and give a small serving bow.
            let lift=3*CGFloat(sin(.pi*phase))
            RosterItemArtwork.draw(.keepsake,friend:friend,in:NSRect(x:79,y:65+lift,width:98,height:72))
            limb(left,NSPoint(x:89,y:94+lift),width:13);limb(right,NSPoint(x:166,y:94+lift),width:13)
        case .kani:
            RosterItemArtwork.draw(.keepsake,friend:friend,in:NSRect(x:83,y:61,width:90,height:78))
            limb(left,NSPoint(x:91,y:92),width:13);limb(right,NSPoint(x:166,y:92),width:13)
            // A narrow cream leaf turns over the stationary book, with the same body.
            if phase > 0.28 && phase < 0.78 {
                let t=CGFloat((phase-0.28)/0.5),width=34*abs(cos(.pi*t))
                let leaf=NSBezierPath();leaf.move(to:NSPoint(x:128,y:78));leaf.line(to:NSPoint(x:128+(t<0.5 ? width:-width),y:86));leaf.line(to:NSPoint(x:128+(t<0.5 ? width:-width),y:128));leaf.line(to:NSPoint(x:128,y:120));leaf.close()
                NSColor(hex:0xFFF2D8).setFill();leaf.fill();NSColor(hex:0xAD8886).setStroke();leaf.lineWidth=1.2;leaf.stroke()
            }
        default: break
        }
    }

    /// Official Usagi art keeps its short rounded paws even in energetic poses.
    /// The approved head and body remain one fixed drawing throughout the motion.
    private func drawUsagiGesture(_ action: RosterAction, left: NSPoint, right: NSPoint,
                                  wave: CGFloat, phase: Double) {
        switch action {
        case .wave:
            paw(root: left, rotation: -1.65 + wave * 0.28, right: false)
            paw(root: right, rotation: 0.05, right: true)
        case .laugh, .surprised, .wake:
            let lift: CGFloat = action == .surprised ? 0.35 : 1.1
            paw(root: left, rotation: -lift + wave * 0.15, right: false)
            paw(root: right, rotation: lift - wave * 0.15, right: true)
        case .pickup:
            paw(root: left, rotation: 0.4 * CGFloat(sin(.pi * phase)), right: false)
            paw(root: right, rotation: -0.4 * CGFloat(sin(.pi * phase)), right: true)
        case .attack:
            let thrust = wave * 9, level = left.y - 9
            let context = NSGraphicsContext.current!.cgContext
            context.saveGState(); context.translateBy(x: 120+thrust, y: level)
            context.rotate(by: -0.035 + wave * 0.06)
            RosterItemArtwork.weapon(friend: .usagi, in: NSRect(x: -200, y: -16, width: 330, height: 32))
            context.restoreGState()
            limb(left, NSPoint(x: left.x+9+thrust, y: level), width: 13)
            limb(right, NSPoint(x: right.x-9+thrust, y: level+4), width: 13)
        case .keepsake:
            let lift = 2 * wave
            RosterItemArtwork.draw(.keepsake, friend: .usagi, in: NSRect(x: 78, y: left.y-41+lift, width: 100, height: 77))
            limb(left, NSPoint(x: 98, y: left.y-7+lift), width: 13)
            limb(right, NSPoint(x: 162, y: right.y-7+lift), width: 13)
        case .sleep: break
        }
    }
}

final class RosterSprites {
    private static var cache: [Friend: RosterSprites] = [:]
    static func shared(_ friend: Friend) -> RosterSprites {
        if let value=cache[friend] {return value};let value=RosterSprites(friend:friend);cache[friend]=value;return value
    }
    let friend: Friend
    let rig: RosterNativeRig?
    var walks: [ChiikawaDirection:[NSImage]] = [:]
    var actions: [RosterAction:[NSImage]] = [:]
    var registration: AttackRegistration?
    private(set) var sleepViewport = NSRect(origin: .zero, size: RosterSleepArtwork.canvas)
    private(set) var usesBundledAtlases = false
    var isReady: Bool { ChiikawaDirection.allCases.allSatisfy { walks[$0]?.count == 24 } && RosterAction.available(for: friend).allSatisfy {actions[$0]?.count == 12} && (!friend.canUseWeapon || registration != nil) }
    private init(friend: Friend) {
        self.friend=friend;rig=RosterNativeRig(friend:friend)
        guard let rig else {return}
        func image(_ rep:NSBitmapImageRep)->NSImage {NSImage(cgImage:rep.cgImage!,size:NSSize(width:rep.pixelsWide,height:rep.pixelsHigh))}
        func mirrored(_ rep:NSBitmapImageRep)->NSImage {
            let result=RosterNativeRig.bitmap(NSSize(width:rep.pixelsWide,height:rep.pixelsHigh)) {}
            for y in 0..<rep.pixelsHigh {for x in 0..<rep.pixelsWide {for c in 0..<4 {result.bitmapData![y*result.bytesPerRow+x*4+c]=rep.bitmapData![y*rep.bytesPerRow+(rep.pixelsWide-1-x)*4+c]}}}
            return image(result)
        }
        usesBundledAtlases = loadBundledAtlases()
        if !usesBundledAtlases {
        guard rig.sleepingArtwork != nil else { return }
        for (pose,left,right) in [(HachiwarePose.front,ChiikawaDirection.down,nil),(.back,.up,nil),(.side,.left,.right),(.frontDiagonal,.downLeft,.downRight),(.backDiagonal,.upLeft,.upRight)] as [(HachiwarePose,ChiikawaDirection,ChiikawaDirection?)] {
            let frames=(0..<24).map {rig.walk(pose,phase:Double($0)/24)}
            walks[left]=frames.map(image)
            if let right {
                let rightFrames=rig.rightBodies[pose] == nil ? frames : (0..<24).map {rig.walk(pose,phase:Double($0)/24,rightFacing:true)}
                walks[right]=rightFrames.map(mirrored)
            }
        }
        for action in RosterAction.available(for: friend) {actions[action]=(0..<12).map {image(rig.action(action,phase:Double($0)/12))}}
        }
        registerSleepViewport()
        guard friend.canUseWeapon else { return }
        let rect=rig.bodyRect(.front,y:44)
        let reference=AttackBodyMetrics(head:rect,feet:34,alpha:CGRect(origin:.zero,size:friend.canvasSize),size:friend.canvasSize)
        let attack=AttackBodyMetrics(head:rect.offsetBy(dx:120,dy:0),feet:34,alpha:CGRect(x:0,y:0,width:440,height:friend.canvasSize.height),size:NSSize(width:440,height:friend.canvasSize.height))
        registration=AttackRegistration(referenceMetrics:reference,frames:[AttackBodyMetrics](repeating:attack,count:12))
    }
    private func loadBundledAtlases() -> Bool {
        guard Bundle.main.bundleURL.pathExtension == "app",
              let root=Bundle.main.resourceURL?.appendingPathComponent("Roster/\(friend.rawValue)") else { return false }
        func frames(_ name:String,cell:NSSize,count:Int) -> [NSImage]? {
            guard let data=try? Data(contentsOf:root.appendingPathComponent(name+".png")),
                  let bitmap=NSBitmapImageRep(data:data),let image=bitmap.decodedArtwork,
                  image.width==Int(cell.width)*6,image.height==Int(cell.height)*(count/6) else { return nil }
            var result:[NSImage]=[]
            for n in 0..<count {
                guard let piece=image.cropping(to:CGRect(x:CGFloat(n%6)*cell.width,y:CGFloat(n/6)*cell.height,width:cell.width,height:cell.height)) else {return nil}
                result.append(NSImage(cgImage:piece,size:cell))
            }
            return result
        }
        var loadedWalks:[ChiikawaDirection:[NSImage]]=[:],loadedActions:[RosterAction:[NSImage]]=[:]
        for direction in ChiikawaDirection.allCases {
            guard let images=frames(direction.rawValue+"-24",cell:friend.canvasSize,count:24) else {return false}
            loadedWalks[direction]=images
        }
        for action in RosterAction.available(for: friend) {
            let cell=action == .attack ? NSSize(width:440,height:friend.canvasSize.height) : action == .sleep ? NSSize(width:256,height:180) : friend.canvasSize
            guard let images=frames(action.rawValue+"-12",cell:cell,count:12) else {return false}
            loadedActions[action]=images
        }
        walks=loadedWalks;actions=loadedActions;return true
    }
    private func registerSleepViewport() {
        guard let frames = actions[.sleep], frames.count == 12 else { return }
        var bounds = NSRect.null
        // The widest inhaled frame and the resting frame share one fixed crop.
        // Registration happens once; drawing never scans alpha or opens PNGs.
        for index in [0, 6] {
            guard let data = frames[index].tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: data) else { continue }
            var left = bitmap.pixelsWide, top = bitmap.pixelsHigh, right = -1, bottom = -1
            for y in 0..<bitmap.pixelsHigh { for x in 0..<bitmap.pixelsWide
                where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.02 {
                    left = min(left, x); right = max(right, x)
                    top = min(top, y); bottom = max(bottom, y)
                }
            }
            if right >= left && bottom >= top {
                bounds = bounds.union(NSRect(x: left, y: bitmap.pixelsHigh-bottom-1,
                    width: right-left+1, height: bottom-top+1))
            }
        }
        if !bounds.isNull {
            sleepViewport = bounds.insetBy(dx: -2, dy: -2).intersection(NSRect(origin: .zero, size: RosterSleepArtwork.canvas))
        }
    }
    func draw(action:RosterAction,in rect:NSRect,elapsed:Double) {
        guard let frames=actions[action],!frames.isEmpty else {return}
        let index=HachiwareSprites.frameIndex(phase:max(0,elapsed)/action.cycle*2 * .pi,count:12)
        let image=frames[index]
        if action == .attack, let registration {image.draw(in:registration.destination(frame:index,in:rect));return}
        if action == .sleep {
            let destination = HomeArtwork.fitted(sleepViewport.size, in: rect)
            image.draw(in: destination, from: sleepViewport, operation: .sourceOver, fraction: 1)
            return
        }
        let scale=min(rect.width/image.size.width,rect.height/image.size.height)
        image.draw(in:NSRect(x:rect.midX-image.size.width*scale/2,y:rect.midY-image.size.height*scale/2,width:image.size.width*scale,height:image.size.height*scale))
    }
}

enum RosterArtwork {
    static func drawEquipment(_ kind:RosterItemKind,friend:Friend,destination:NSRect,scale:CGFloat,
                              facing:CGFloat,pose:HachiwarePose,phase:Double,pickup:Double? = nil) {
        guard RosterItemKind.available(for: friend).contains(kind) else { return }
        let context=NSGraphicsContext.current!.cgContext
        context.saveGState();context.translateBy(x:destination.minX,y:destination.minY);context.scaleBy(x:scale,y:scale)
        if pose.canMirror && facing>0 {context.translateBy(x:256,y:0);context.scaleBy(x:-1,y:1)}
        let bob:CGFloat=4.2*CGFloat(sin(phase*2))
        var item:NSRect
        switch kind {
        case .weapon:item=NSRect(x:162,y:39-bob,width:65,height:148)
        case .keepsake:item=friend == .momonga ? NSRect(x:165,y:188-bob,width:47,height:47) : NSRect(x:94,y:62-bob,width:68,height:68)
        }
        if let t=pickup,kind != .weapon {
            let ease=CGFloat(t*t*(3-2*t));item.origin.y=25+42*ease
        }
        RosterItemArtwork.draw(kind,friend:friend,in:item);context.restoreGState()
    }
    static func draw(_ friend:Friend,in rect:NSRect,time:Double,walking:Bool,facing:CGFloat,phase:Double,pose:HachiwarePose,visual:RosterVisual) {
        let sprites=RosterSprites.shared(friend)
        guard sprites.isReady else {return}
        NSGraphicsContext.current?.imageInterpolation = .high
        let canvas=friend.canvasSize,scale=min(rect.width/canvas.width,rect.height/canvas.height)
        let destination=NSRect(x:rect.midX-canvas.width*scale/2,y:rect.midY-canvas.height*scale/2,width:canvas.width*scale,height:canvas.height*scale)
        if let action=visual.action, RosterAction.available(for: friend).contains(action) {
            sprites.draw(action:action,in:rect,elapsed:visual.elapsed)
            if action == .pickup,let kind=visual.equipped {
                drawEquipment(kind,friend:friend,destination:destination,scale:scale,facing:-1,pose:.front,phase:0,
                              pickup:Double(HachiwareSprites.frameIndex(phase:max(0,visual.elapsed)/action.cycle*2 * .pi,count:12))/12)
            }
            return
        }
        let shown=walking ? pose:HachiwarePose.front
        let direction=ChiikawaDirection.resolve(pose:shown,facing:facing)
        let index=walking ? HachiwareSprites.frameIndex(phase:phase,count:24):0
        guard let frame=sprites.walks[direction]?[index] else {return}
        let behind=shown == .back || shown == .backDiagonal
        let paintPhase=walking ? Double(index)/24*2 * .pi : 0
        if visual.equipped == .weapon && friend == .rakko {
            RakkoSwordArtwork.carried(pose:shown,facing:facing,phase:paintPhase,destination:destination,scale:scale,foreground:false)
            frame.draw(in:destination)
            RakkoSwordArtwork.carried(pose:shown,facing:facing,phase:paintPhase,destination:destination,scale:scale,foreground:true)
            return
        }
        if let kind=visual.equipped,behind {drawEquipment(kind,friend:friend,destination:destination,scale:scale,facing:facing,pose:shown,phase:paintPhase)}
        frame.draw(in:destination)
        if let kind=visual.equipped,!behind {drawEquipment(kind,friend:friend,destination:destination,scale:scale,facing:facing,pose:shown,phase:paintPhase)}
    }
}

enum RosterItemArtwork {
    private static let generatedItems: [Friend: NSImage] = Dictionary(uniqueKeysWithValues:
        Friend.expansionOrder.filter(\.usesNewFriendRig).compactMap { friend in
            HachiwareSprites.assetURL(named:"\(friend.rawValue)-rig-item-v38").flatMap(NSImage.init(contentsOf:)).map { (friend,$0) }
        })
    static func flower(in rect: NSRect) {
        let c=NSGraphicsContext.current!.cgContext;c.saveGState();c.translateBy(x:rect.midX,y:rect.midY);c.scaleBy(x:rect.width/64,y:rect.height/64)
        for i in 0..<5 {
            c.saveGState();c.rotate(by:CGFloat(i)*2 * .pi/5)
            let petal=NSBezierPath(ovalIn:NSRect(x:-12,y:0,width:24,height:29))
            NSColor(hex:0xF3C1D2).setFill();petal.fill();NSColor(hex:0x835C61).setStroke();petal.lineWidth=2;petal.stroke();c.restoreGState()
        }
        NSColor(hex:0xF5DA88).setFill();NSBezierPath(ovalIn:NSRect(x:-8,y:-8,width:16,height:16)).fill()
        c.restoreGState()
    }
    static func cup(in rect: NSRect) {
        let c=NSGraphicsContext.current!.cgContext;c.saveGState();c.translateBy(x:rect.minX,y:rect.minY);c.scaleBy(x:rect.width/46,y:rect.height/62)
        let ink=NSColor(hex:0x68483A)
        let handle=NSBezierPath(roundedRect:NSRect(x:30,y:15,width:15,height:29),xRadius:7,yRadius:7)
        ink.setStroke();handle.lineWidth=5;handle.stroke()
        let mug=NSBezierPath(roundedRect:NSRect(x:4,y:5,width:31,height:48),xRadius:5,yRadius:5)
        NSColor(hex:0xEAC074).setFill();mug.fill();ink.setStroke();mug.lineWidth=2.5;mug.stroke()
        NSColor(hex:0xFFF5D8).setFill();NSBezierPath(ovalIn:NSRect(x:4,y:46,width:31,height:11)).fill()
        ink.setStroke();let rim=NSBezierPath(ovalIn:NSRect(x:4,y:46,width:31,height:11));rim.lineWidth=2;rim.stroke()
        NSColor(hex:0xF6DDA3).setStroke();let shine=NSBezierPath();shine.move(to:NSPoint(x:11,y:16));shine.line(to:NSPoint(x:11,y:40));shine.lineWidth=3;shine.stroke();c.restoreGState()
    }
    static func snack(in rect: NSRect) {
        let c=NSGraphicsContext.current!.cgContext;c.saveGState();c.translateBy(x:rect.minX,y:rect.minY);c.scaleBy(x:rect.width/55,y:rect.height/50)
        let ink=NSColor(hex:0x68483A),plate=NSBezierPath(ovalIn:NSRect(x:1,y:3,width:53,height:23))
        NSColor(hex:0xF4E5CE).setFill();plate.fill();ink.setStroke();plate.lineWidth=2.3;plate.stroke()
        let food=NSBezierPath();food.move(to:NSPoint(x:8,y:17));food.line(to:NSPoint(x:18,y:37));food.line(to:NSPoint(x:46,y:24));food.line(to:NSPoint(x:39,y:12));food.close()
        NSColor(hex:0xD89769).setFill();food.fill();ink.setStroke();food.lineWidth=2;food.stroke()
        for i in 0..<3 {let line=NSBezierPath();line.move(to:NSPoint(x:18+CGFloat(i)*7,y:28-CGFloat(i)*3));line.line(to:NSPoint(x:23+CGFloat(i)*7,y:19-CGFloat(i)*3));line.lineWidth=1.5;line.stroke()};c.restoreGState()
    }
    static func weapon(friend:Friend,in rect:NSRect) {
        guard friend == .usagi else { return }
        let context=NSGraphicsContext.current!.cgContext;context.saveGState()
        context.translateBy(x:rect.minX,y:rect.minY);context.scaleBy(x:rect.width/330,y:rect.height/32)
        let ink=NSColor(hex:0x68483A),color=friend == .usagi ? NSColor(hex:0xE6BE5D):friend.color
        let pole=NSBezierPath(roundedRect:NSRect(x:0,y:10,width:330,height:12),xRadius:5,yRadius:5)
        color.setFill();pole.fill();ink.setStroke();pole.lineWidth=3;pole.stroke()
        for x:CGFloat in [5,316] {
            let end=NSBezierPath(ovalIn:NSRect(x:x-4,y:2,width:23,height:28));color.setFill();end.fill();ink.setStroke();end.lineWidth=3;end.stroke()
        }
        context.restoreGState()
    }
    static func draw(_ kind:RosterItemKind,friend:Friend,in rect:NSRect) {
        guard RosterItemKind.available(for: friend).contains(kind) else { return }
        if kind == .weapon && friend == .rakko {
            RakkoSwordArtwork.sheathed(in:HomeArtwork.fitted(NSSize(width:40,height:160),in:rect))
            return
        }
        if kind == .keepsake, let image=generatedItems[friend] {
            let scale=min(rect.width/image.size.width,rect.height/image.size.height)
            image.draw(in:NSRect(x:rect.midX-image.size.width*scale/2,y:rect.midY-image.size.height*scale/2,width:image.size.width*scale,height:image.size.height*scale))
            return
        }
        switch kind {
        case .weapon:
            let context=NSGraphicsContext.current!.cgContext;context.saveGState()
            context.translateBy(x:rect.midX,y:rect.midY);context.rotate(by:.pi/2)
            weapon(friend:friend,in:NSRect(x:-rect.height/2,y:-rect.width*0.14,width:rect.height,height:rect.width*0.28));context.restoreGState()
        case .keepsake:
            let context=NSGraphicsContext.current!.cgContext;context.saveGState();context.translateBy(x:rect.minX,y:rect.minY);context.scaleBy(x:rect.width/64,y:rect.height/64)
            if friend == .momonga {
                flower(in: NSRect(x: 1,y: 1,width: 62,height: 62))
            } else if friend == .kurimanju {
                cup(in: NSRect(x: 2,y: 9,width: 38,height: 51))
                snack(in: NSRect(x: 34,y: 3,width: 30,height: 30))
            } else {
                let pudding=NSBezierPath();pudding.move(to:NSPoint(x:10,y:13));pudding.line(to:NSPoint(x:18,y:49));pudding.line(to:NSPoint(x:47,y:49));pudding.line(to:NSPoint(x:55,y:13));pudding.close();NSColor(hex:friend == .usagi ? 0xF1D17E:0xD8B88D).setFill();pudding.fill();NSColor(hex:0x68483A).setStroke();pudding.lineWidth=2.5;pudding.stroke();NSColor(hex:0xAE7952).setFill();NSBezierPath(ovalIn:NSRect(x:17,y:43,width:31,height:12)).fill()
            }
            context.restoreGState()
        }
    }
}
