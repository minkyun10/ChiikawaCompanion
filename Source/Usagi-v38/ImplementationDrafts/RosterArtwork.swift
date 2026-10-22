import AppKit

/// Source anatomy comes from the reviewed imagegen rig. All in-betweens use one
/// deterministic native skeleton, shared foot paths and a half-cycle offset.
final class RosterNativeRig {
    let friend: Friend
    let bodies: [HachiwarePose: NSImage]
    let arm: NSImage
    let foot: NSImage
    let paper: NSColor
    let ink = NSColor(hex: 0x68483A)
    var height: CGFloat { friend == .usagi ? 270 : 194 }
    var canvas: NSSize { friend.canvasSize }
    init?(friend: Friend) {
        func load(_ name: String) -> NSImage? {
            HachiwareSprites.assetURL(named: "\(friend.rawValue)-rig-\(name)-v38").flatMap(NSImage.init(contentsOf:))
        }
        var bodies: [HachiwarePose: NSImage] = [:]
        for (pose, name) in [(HachiwarePose.front,"front"),(.side,"side"),(.back,"back"),(.frontDiagonal,"front-diagonal"),(.backDiagonal,"back-diagonal")] {
            guard let image = load(name) else { return nil }; bodies[pose] = image
        }
        guard let arm = load("arm"), let foot = load("foot") else { return nil }
        self.friend = friend; self.bodies = bodies; self.arm = arm; self.foot = foot
        if let data = bodies[.front]!.tiffRepresentation, let rep = NSBitmapImageRep(data: data),
           let color = rep.colorAt(x: Int(Double(rep.pixelsWide)*0.48), y: Int(Double(rep.pixelsHigh)*0.82))?.usingColorSpace(.deviceRGB),
           color.redComponent > 0.7, color.greenComponent > 0.6 { paper = color }
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
        let xs = (0..<rep.pixelsWide).filter { (rep.colorAt(x: $0,y: row)?.alphaComponent ?? 0)>0.5 }
        let edge = right ? xs.last ?? rep.pixelsWide-1 : xs.first ?? 0
        return NSPoint(x: rect.minX+CGFloat(edge)/CGFloat(rep.pixelsWide)*rect.width+(right ? -4 : 4),y: y+72)
    }
    func stroke(_ points: [NSPoint], width: CGFloat, color: NSColor) {
        let path = NSBezierPath(); path.move(to: points[0]); points.dropFirst().forEach { path.line(to: $0) }
        path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round; color.setStroke(); path.stroke()
    }
    func limb(_ start: NSPoint, _ end: NSPoint, width: CGFloat = 13) {
        stroke([start,end],width: width,color: ink); stroke([start,end],width: width-5,color: paper)
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
    func footPose(_ phase: Double) -> (CGFloat, CGFloat, CGFloat) {
        let t = phase-floor(phase), stride: CGFloat = 62.7/(4*(132.0/256.0))
        if t < 0.5 { return (-stride+4*stride*CGFloat(t),26,CGFloat(-28+120*t)*.pi/180) }
        let u = t*2-1, ease = u*u*(3-2*u)
        let h00 = 2*u*u*u-3*u*u+1, h10 = u*u*u-2*u*u+u, h01 = -2*u*u*u+3*u*u, h11 = u*u*u-u*u
        return (stride*CGFloat(h00+2*h10-h01+2*h11),26+13*CGFloat(pow(sin(.pi*u),2)),CGFloat(32-60*ease)*.pi/180)
    }
    func walk(_ pose: HachiwarePose, phase: Double) -> NSBitmapImageRep {
        let y = 44-4.2*CGFloat(sin(4*.pi*phase)), rect = bodyRect(pose,y: y)
        let projection: CGVector = pose == .side ? CGVector(dx: 1,dy: 0)
            : pose == .front ? CGVector(dx: 0,dy: 0.25) : pose == .back ? CGVector(dx: 0,dy: -0.25)
            : CGVector(dx: 0.65,dy: pose == .frontDiagonal ? 0.28 : -0.28)
        return Self.bitmap(canvas) {
            for index in [1,0] {
                let p = footPose(phase+Double(index)*0.5), root: CGFloat = pose == .side ? 0 : index == 0 ? -15 : 15
                let x = 128+root+projection.dx*p.0, yy = p.1+projection.dy*p.0
                limb(NSPoint(x: x,y: yy+16),NSPoint(x: 128+root+(x-128-root)*0.35,y: y+22))
                let context = NSGraphicsContext.current!.cgContext
                context.saveGState(); context.translateBy(x: x,y: yy+9); context.rotate(by: p.2*(pose == .side ? 1 : 0.22))
                foot.draw(in: NSRect(x: -9,y: -9,width: 18,height: 24)); context.restoreGState()
            }
            bodies[pose]!.draw(in: rect)
            let swing = CGFloat(cos(2*.pi*phase))*0.10
            let near = root(pose,y: y,right: false), far = root(pose,y: y,right: true)
            if pose != .backDiagonal { paw(root: far,rotation: -swing,right: true) }
            paw(root: near,rotation: swing,right: false)
        }
    }
    func face(_ action: RosterAction, y: CGFloat, phase: Double) {
        let eyesY = y+height*(friend == .usagi ? 0.48 : 0.63), mouthY = y+height*(friend == .usagi ? 0.35 : 0.47)
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
        if action == .study || action == .attack || action == .surprised {
            paper.setFill(); NSBezierPath(ovalIn: NSRect(x: 113,y: mouthY-17,width: 30,height: 33)).fill()
            ink.setFill(); NSBezierPath(ovalIn: NSRect(x: 119,y: mouthY-10,width: 18,height: action == .surprised ? 20 : 22)).fill()
            if action != .surprised {
                NSColor(hex: 0xEC9AA8).setFill(); NSBezierPath(roundedRect: NSRect(x: 123,y: mouthY-12,width: 11,height: 12),xRadius: 5,yRadius: 5).fill()
            }
        }
    }
    func action(_ action: RosterAction, phase: Double) -> NSBitmapImageRep {
        let size = action == .attack ? NSSize(width: 440,height: canvas.height) : action == .sleep ? NSSize(width: 256,height: 180) : canvas
        return Self.bitmap(size) {
            let context = NSGraphicsContext.current!.cgContext
            if action == .attack { context.translateBy(x: 120,y: 0) }
            if action == .sleep {
                NSColor(hex: 0x9EA77B).setFill(); NSBezierPath(roundedRect: NSRect(x: 10,y: 32,width: 236,height: 80),xRadius: 16,yRadius: 16).fill()
                context.saveGState(); context.translateBy(x: 117,y: 80); context.rotate(by: .pi/2);context.scaleBy(x: 0.62,y: 0.62);context.translateBy(x: -128,y: -height/2-44)
                bodies[.front]!.draw(in: bodyRect(.front,y: 44)); face(.sleep,y: 44,phase: phase); context.restoreGState()
                friend.color.withAlphaComponent(0.95).setFill(); let blanket=NSBezierPath(roundedRect: NSRect(x: 119,y: 36,width: 125,height: 78),xRadius: 13,yRadius: 13)
                blanket.fill(); ink.setStroke(); blanket.lineWidth=3.5;blanket.stroke();return
            }
            let y: CGFloat = 44+(action == .pickup ? -8*CGFloat(sin(.pi*phase)) : action == .wake ? 4*CGFloat(sin(.pi*phase)) : 0)
            for x: CGFloat in [113,143] { foot.draw(in: NSRect(x: x-9,y: 26,width: 18,height: 24)) }
            bodies[.front]!.draw(in: bodyRect(.front,y: y)); face(action,y: y,phase: phase)
            let left = root(.front,y: y,right: false), right = root(.front,y: y,right: true)
            let wave = CGFloat(sin(2*.pi*phase))
            switch action {
            case .wave, .wake:
                limb(left,NSPoint(x: left.x-7,y: left.y+30+wave*8)); limb(right,NSPoint(x: right.x+6,y: right.y+(action == .wake ? 30 : -13)))
            case .laugh, .surprised:
                limb(left,NSPoint(x: left.x-7,y: left.y+10+abs(wave)*7));limb(right,NSPoint(x: right.x+7,y: right.y+10+abs(wave)*7))
            case .pickup:
                limb(left,NSPoint(x: 95,y: 48-8*wave));limb(right,NSPoint(x: 157,y: 47-8*wave))
                RosterItemArtwork.draw(.keepsake,friend: friend,in: NSRect(x: 96,y: 25+18*CGFloat(sin(.pi*phase)),width: 56,height: 56))
            case .camera:
                RosterItemArtwork.draw(.camera,friend: friend,in: NSRect(x: 82,y: 61+4*wave,width: 92,height: 80))
                limb(left,NSPoint(x: 95,y: 90+4*wave));limb(right,NSPoint(x: 162,y: 90+4*wave))
                if phase > 0.42 && phase < 0.58 { NSColor.white.withAlphaComponent(0.9).setFill();NSBezierPath(ovalIn: NSRect(x: 124,y: 91,width: 11,height: 11)).fill() }
            case .guitar:
                RosterItemArtwork.draw(.guitar,friend: friend,in: NSRect(x: 54,y: 38,width: 157,height: 122))
                limb(left,NSPoint(x: 108+wave*7,y: 85-wave*6));limb(right,NSPoint(x: 184,y: 114))
                ("♪" as NSString).draw(at: NSPoint(x: 197,y: 139+abs(wave)*8),withAttributes:[.font:NSFont.systemFont(ofSize: 24),.foregroundColor:friend.color])
            case .attack:
                let thrust = CGFloat(sin(2*.pi*phase))*25
                context.saveGState(); context.translateBy(x: 120+thrust,y: 74);context.rotate(by: -0.10+wave*0.13)
                RosterItemArtwork.weapon(friend: friend,in: NSRect(x: -200,y: -8,width: 330,height: 32));context.restoreGState()
                limb(left,NSPoint(x: 82+thrust,y: 77));limb(right,NSPoint(x: 165+thrust,y: 84))
            case .study:
                ActivitySpotArtwork.draw(.desk,in: NSRect(x: 30,y: 3,width: 196,height: 155),owner: friend)
                limb(left,NSPoint(x: 101+wave*5,y: 89+wave*2));limb(right,NSPoint(x: 172,y: 84))
                stroke([NSPoint(x: 101+wave*5,y: 90+wave*2),NSPoint(x: 113+wave*5,y: 118+wave*2)],width: 4,color: NSColor(hex: 0xBA7F53))
            case .eat, .keepsake:
                if action == .eat {
                    ActivitySpotArtwork.draw(.rice,in: NSRect(x: 66,y: 25,width: 124,height: 119),owner: friend)
                    limb(left,NSPoint(x: 100,y: 92));limb(right,NSPoint(x: 157-wave*12,y: 111+wave*13))
                    stroke([NSPoint(x: 157-wave*12,y: 111+wave*13),NSPoint(x: 132,y: 125+wave*8)],width: 2.6,color: NSColor(hex: 0xAD7954))
                } else {
                    RosterItemArtwork.draw(.keepsake,friend: friend,in: NSRect(x: 94,y: 62+wave*5,width: 68,height: 68))
                    limb(left,NSPoint(x: 106,y: 92));limb(right,NSPoint(x: 151,y: 92+wave*5))
                }
            case .vomit:
                paw(root: left,rotation: 0,right: false);paw(root: right,rotation: 0,right: true)
                let mouthY=y+height*(friend == .usagi ? 0.35 : 0.47)
                let length=max(0,CGFloat(sin(.pi*phase)))*(mouthY-22)
                let path=NSBezierPath();path.move(to:NSPoint(x:128,y:mouthY));path.curve(to:NSPoint(x:124+wave*4,y:mouthY-length),controlPoint1:NSPoint(x:130,y:mouthY-length*0.4),controlPoint2:NSPoint(x:120,y:mouthY-length*0.7))
                path.lineWidth=14;path.lineCapStyle = .round;ink.setStroke();path.stroke();path.lineWidth=10;NSColor(hex:0xEAD4B4).setStroke();path.stroke()
                ActivitySpotArtwork.draw(.furball,in:NSRect(x:95,y:max(5,mouthY-length-35),width:60,height:60),owner:friend)
            case .sleep: break
            }
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
    var isReady: Bool { ChiikawaDirection.allCases.allSatisfy { walks[$0]?.count == 24 } && RosterAction.allCases.allSatisfy {actions[$0]?.count == 12} && registration != nil }
    private init(friend: Friend) {
        self.friend=friend;rig=RosterNativeRig(friend:friend)
        guard let rig else {return}
        func image(_ rep:NSBitmapImageRep)->NSImage {NSImage(cgImage:rep.cgImage!,size:NSSize(width:rep.pixelsWide,height:rep.pixelsHigh))}
        func mirrored(_ rep:NSBitmapImageRep)->NSImage {
            let result=RosterNativeRig.bitmap(NSSize(width:rep.pixelsWide,height:rep.pixelsHigh)) {}
            for y in 0..<rep.pixelsHigh {for x in 0..<rep.pixelsWide {for c in 0..<4 {result.bitmapData![y*result.bytesPerRow+x*4+c]=rep.bitmapData![y*rep.bytesPerRow+(rep.pixelsWide-1-x)*4+c]}}}
            return image(result)
        }
        for (pose,left,right) in [(HachiwarePose.front,ChiikawaDirection.down,nil),(.back,.up,nil),(.side,.left,.right),(.frontDiagonal,.downLeft,.downRight),(.backDiagonal,.upLeft,.upRight)] as [(HachiwarePose,ChiikawaDirection,ChiikawaDirection?)] {
            let frames=(0..<24).map {rig.walk(pose,phase:Double($0)/24)}
            walks[left]=frames.map(image);if let right {walks[right]=frames.map(mirrored)}
        }
        for action in RosterAction.allCases {actions[action]=(0..<12).map {image(rig.action(action,phase:Double($0)/12))}}
        let rect=rig.bodyRect(.front,y:44)
        let reference=AttackBodyMetrics(head:rect,feet:26,alpha:CGRect(origin:.zero,size:friend.canvasSize),size:friend.canvasSize)
        let attack=AttackBodyMetrics(head:rect.offsetBy(dx:120,dy:0),feet:26,alpha:CGRect(x:0,y:0,width:440,height:friend.canvasSize.height),size:NSSize(width:440,height:friend.canvasSize.height))
        registration=AttackRegistration(referenceMetrics:reference,frames:[AttackBodyMetrics](repeating:attack,count:12))
    }
    func draw(action:RosterAction,in rect:NSRect,elapsed:Double) {
        guard let frames=actions[action],!frames.isEmpty else {return}
        let index=HachiwareSprites.frameIndex(phase:max(0,elapsed)/action.cycle*2 * .pi,count:12)
        let image=frames[index]
        if action == .attack, let registration {image.draw(in:registration.destination(frame:index,in:rect));return}
        let scale=min(rect.width/image.size.width,rect.height/image.size.height)
        image.draw(in:NSRect(x:rect.midX-image.size.width*scale/2,y:rect.midY-image.size.height*scale/2,width:image.size.width*scale,height:image.size.height*scale))
    }
}

enum RosterArtwork {
    static func draw(_ friend:Friend,in rect:NSRect,time:Double,walking:Bool,facing:CGFloat,phase:Double,pose:HachiwarePose,visual:RosterVisual) {
        let sprites=RosterSprites.shared(friend)
        guard sprites.isReady else {return}
        NSGraphicsContext.current?.imageInterpolation = .high
        if let action=visual.action {sprites.draw(action:action,in:rect,elapsed:visual.elapsed);return}
        let direction=ChiikawaDirection.resolve(pose:walking ? pose : .front,facing:facing)
        let index=walking ? HachiwareSprites.frameIndex(phase:phase,count:24):0
        guard let frame=sprites.walks[direction]?[index] else {return}
        let scale=min(rect.width/frame.size.width,rect.height/frame.size.height)
        let destination=NSRect(x:rect.midX-frame.size.width*scale/2,y:rect.midY-frame.size.height*scale/2,width:frame.size.width*scale,height:frame.size.height*scale)
        let context=NSGraphicsContext.current!.cgContext
        frame.draw(in:destination)
        if let equipped=visual.equipped {
            context.saveGState();context.translateBy(x:destination.minX,y:destination.minY);context.scaleBy(x:scale,y:scale)
            if pose.canMirror && facing>0 {context.translateBy(x:256,y:0);context.scaleBy(x:-1,y:1)}
            let y:CGFloat=44-4.2*CGFloat(sin(phase*2))
            RosterItemArtwork.draw(equipped,friend:friend,in:NSRect(x:equipped == .weapon ? 162:93,y:y-5,width:equipped == .weapon ? 65:75,height:equipped == .weapon ? 148:78))
            context.restoreGState()
        }
    }
}

enum RosterItemArtwork {
    static func weapon(friend:Friend,in rect:NSRect) {
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
        switch kind {
        case .camera:ItemArtwork.draw(.camera,in:rect)
        case .guitar:ItemArtwork.draw(.guitar,in:rect)
        case .weapon:
            let context=NSGraphicsContext.current!.cgContext;context.saveGState()
            context.translateBy(x:rect.midX,y:rect.midY);context.rotate(by:.pi/2)
            weapon(friend:friend,in:NSRect(x:-rect.height/2,y:-rect.width*0.14,width:rect.height,height:rect.width*0.28));context.restoreGState()
        case .keepsake:
            let context=NSGraphicsContext.current!.cgContext;context.saveGState();context.translateBy(x:rect.minX,y:rect.minY);context.scaleBy(x:rect.width/64,y:rect.height/64)
            if friend == .momonga {
                let leaf=NSBezierPath();leaf.move(to:NSPoint(x:12,y:12));leaf.curve(to:NSPoint(x:54,y:53),controlPoint1:NSPoint(x:7,y:45),controlPoint2:NSPoint(x:37,y:58));leaf.curve(to:NSPoint(x:12,y:12),controlPoint1:NSPoint(x:61,y:19),controlPoint2:NSPoint(x:30,y:7));NSColor(hex:0xA6C995).setFill();leaf.fill();NSColor(hex:0x68483A).setStroke();leaf.lineWidth=2.5;leaf.stroke()
            } else {
                let pudding=NSBezierPath();pudding.move(to:NSPoint(x:10,y:13));pudding.line(to:NSPoint(x:18,y:49));pudding.line(to:NSPoint(x:47,y:49));pudding.line(to:NSPoint(x:55,y:13));pudding.close();NSColor(hex:friend == .usagi ? 0xF1D17E:0xD8B88D).setFill();pudding.fill();NSColor(hex:0x68483A).setStroke();pudding.lineWidth=2.5;pudding.stroke();NSColor(hex:0xAE7952).setFill();NSBezierPath(ovalIn:NSRect(x:17,y:43,width:31,height:12)).fill()
            }
            context.restoreGState()
        }
    }
}
