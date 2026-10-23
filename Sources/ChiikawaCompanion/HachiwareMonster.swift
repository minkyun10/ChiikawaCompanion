import AppKit

/// The approved cutout rig is animated only while exporting the application.
/// The live desktop selects decoded atlas frames, as it does for normal Hachiware.
final class HachiwareMonsterRig {
    static let canvas = NSSize(width: 256, height: 256)
    static let sleepCanvas = NSSize(width: 256, height: 180)
    let bodies: [HachiwarePose: NSImage]
    let arm: NSImage
    let foot: NSImage
    let tail: NSImage
    let sleeper: NSImage
    let paper = NSColor.white
    let ink = NSColor(hex: 0x111111)
    private let roots: [HachiwarePose: (CGFloat, CGFloat)]

    init?() {
        func load(_ part: String) -> NSImage? {
            HachiwareSprites.assetURL(named: "hachiware-monster-rig-\(part)-v53").flatMap(NSImage.init(contentsOf:))
        }
        var bodies: [HachiwarePose: NSImage] = [:], roots: [HachiwarePose: (CGFloat, CGFloat)] = [:]
        for (pose, name) in [(HachiwarePose.front,"front"),(.side,"side"),(.back,"back"),
                             (.frontDiagonal,"front-diagonal"),(.backDiagonal,"back-diagonal")] {
            guard let image = load(name), let data = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: data) else { return nil }
            bodies[pose] = image
            let y = Int(CGFloat(rep.pixelsHigh) * 0.60)
            let xs = (0..<rep.pixelsWide).filter { (rep.colorAt(x:$0,y:y)?.alphaComponent ?? 0) > 0.5 }
            guard let left = xs.first, let right = xs.last else { return nil }
            roots[pose] = (CGFloat(left)/CGFloat(rep.pixelsWide), CGFloat(right)/CGFloat(rep.pixelsWide))
        }
        guard let arm = load("arm"), let foot = load("foot"), let tail = load("tail"),
              let url = HachiwareSprites.assetURL(named: "hachiware-monster-sleep-v53"),
              let data = try? Data(contentsOf: url), let rep = NSBitmapImageRep(data: data),
              let full = rep.decodedArtwork else { return nil }
        var bounds = CGRect.null
        for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide where (rep.colorAt(x:x,y:y)?.alphaComponent ?? 0) > 0.02 {
            bounds = bounds.union(CGRect(x:x,y:y,width:1,height:1))
        } }
        guard !bounds.isNull, let crop = full.cropping(to: bounds.integral) else { return nil }
        self.bodies = bodies; self.roots = roots; self.arm = arm; self.foot = foot; self.tail = tail
        sleeper = NSImage(cgImage:crop,size:NSSize(width:crop.width,height:crop.height))
    }

    func bodyRect(_ pose: HachiwarePose, y: CGFloat) -> NSRect {
        let image = bodies[pose]!, height: CGFloat = 194
        return NSRect(x:128-image.size.width/image.size.height*height/2,y:y,
                      width:image.size.width/image.size.height*height,height:height)
    }
    func root(_ pose: HachiwarePose, y: CGFloat, right: Bool) -> NSPoint {
        let rect = bodyRect(pose,y:y), edges = roots[pose]!
        return NSPoint(x:rect.minX+(right ? edges.1 : edges.0)*rect.width+(right ? -6 : 6),y:y+77.6)
    }
    func stroke(_ points: [NSPoint], width: CGFloat, color: NSColor) {
        let path = NSBezierPath(); path.move(to:points[0]); points.dropFirst().forEach { path.line(to:$0) }
        path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round
        color.setStroke(); path.stroke()
    }
    func drawArm(at root: NSPoint, angle: CGFloat, right: Bool) {
        let context = NSGraphicsContext.current!.cgContext
        // The open raster root overlaps the white body. A white joint removes
        // the body's old outline under the arm, rather than leaving detached ovals.
        paper.setFill(); NSBezierPath(ovalIn:NSRect(x:root.x-11,y:root.y-10,width:22,height:20)).fill()
        context.saveGState(); context.translateBy(x:root.x,y:root.y); context.rotate(by:angle)
        if right { context.scaleBy(x:-1,y:1) }
        let height: CGFloat = 53, width = height*arm.size.width/(arm.size.height*0.88)
        arm.draw(in:NSRect(x:-width/2,y:-height,width:width,height:height),
                 from:NSRect(x:0,y:0,width:arm.size.width,height:arm.size.height*0.88),operation:.sourceOver,fraction:1)
        context.restoreGState()
    }
    func drawFoot(x: CGFloat, y: CGFloat, angle: CGFloat, rear: Bool) {
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState(); context.translateBy(x:x,y:y+16); context.rotate(by:angle)
        let height: CGFloat = 40, width = height*foot.size.width/(foot.size.height*0.90)
        if rear {
            let heel = NSBezierPath(roundedRect:NSRect(x:-width/2,y:-16,width:width,height:34),xRadius:8,yRadius:8)
            paper.setFill(); heel.fill(); ink.setStroke(); heel.lineWidth = 2.2; heel.stroke()
            context.restoreGState(); return
        }
        // Rear views hide the forward-facing mint toes behind the heel surface.
        let crop = rear ? NSRect(x:0,y:foot.size.height*0.20,width:foot.size.width,height:foot.size.height*0.70)
                        : NSRect(x:0,y:0,width:foot.size.width,height:foot.size.height*0.90)
        foot.draw(in:NSRect(x:-width/2,y:-16,width:width,height:rear ? 34:height),from:crop,operation:.sourceOver,fraction:1)
        context.restoreGState()
    }
    func drawTail(_ pose: HachiwarePose, y: CGFloat, phase: Double) {
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState()
        let rear = pose == .back || pose == .backDiagonal
        if rear { context.translateBy(x:256,y:0); context.scaleBy(x:-1,y:1) }
        let width: CGFloat = pose == .side ? 88 : 94
        let height = width/tail.size.width*tail.size.height
        let origin = NSPoint(x:145,y:y+6)
        context.translateBy(x:origin.x,y:origin.y); context.rotate(by:CGFloat(sin(phase*2 * .pi))*0.025)
        tail.draw(in:NSRect(x:0,y:0,width:width,height:height))
        context.restoreGState()
    }
    /// Identical stance/swing paths, with the right leg exactly half a cycle later.
    static func footPose(_ phase: Double) -> (travel: CGFloat, lift: CGFloat, angle: CGFloat) {
        let t = phase-floor(phase), stride = WalkingGait.distancePerCycle/(4*(132.0/256.0))
        if t < 0.5 { return (-stride+4*stride*CGFloat(t),0,CGFloat(-28+120*t) * .pi/180) }
        let u = t*2-1, ease = u*u*(3-2*u)
        let h00 = 2*u*u*u-3*u*u+1, h10 = u*u*u-2*u*u+u
        let h01 = -2*u*u*u+3*u*u, h11 = u*u*u-u*u
        return (stride*CGFloat(h00+2*h10-h01+2*h11),11*CGFloat(pow(sin(.pi*u),2)),CGFloat(32-60*ease) * .pi/180)
    }
    func walk(_ pose: HachiwarePose, phase: Double) -> NSBitmapImageRep {
        let rear = pose == .back || pose == .backDiagonal
        let y = 42-4.2*CGFloat(sin(4 * .pi*phase))
        let projection: CGVector = pose == .side ? CGVector(dx:1,dy:0)
            : pose == .front ? CGVector(dx:0,dy:0.25) : pose == .back ? CGVector(dx:0,dy:-0.25)
            : CGVector(dx:0.65,dy:pose == .frontDiagonal ? 0.28:-0.28)
        return RosterNativeRig.bitmap(Self.canvas) {
            var joins: [[NSPoint]] = []
            if !rear { drawTail(pose,y:y,phase:phase) }
            if pose == .side { drawArm(at:root(pose,y:y,right:true),angle:-CGFloat(cos(2 * .pi*phase))*0.22,right:true) }
            for index in [1,0] {
                let step = Self.footPose(phase+Double(index)*0.5)
                let spread: CGFloat = pose == .side ? 0 : index == 0 ? -17:17
                let x = 128+spread+projection.dx*step.travel, footY = 22+step.lift+projection.dy*step.travel
                let join = [NSPoint(x:128+spread+projection.dx*step.travel*0.3,y:y+20),
                            NSPoint(x:x,y:footY+(rear ? 10:18))]
                stroke(join,width:19,color:ink); joins.append(join)
                drawFoot(x:x,y:footY,
                         angle:step.angle*(pose == .side ? 0.7:0.15),rear:rear)
            }
            bodies[pose]!.draw(in:bodyRect(pose,y:y))
            // Open the parent's lower outline at both leg roots, preserving
            // the reviewed shared foot paths and all three mint toe claws.
            for join in joins { stroke(join,width:13,color:paper) }
            if rear { drawTail(pose,y:y,phase:phase) }
            if pose != .side { drawArm(at:root(pose,y:y,right:true),angle:-CGFloat(cos(2 * .pi*phase))*0.22,right:true) }
            drawArm(at:root(pose,y:y,right:false),angle:CGFloat(cos(2 * .pi*phase))*0.22,right:false)
        }
    }
    func face(_ action: HachiwareAction, y: CGFloat) {
        if action == .laugh {
            for x: CGFloat in [103,153] {
                paper.setFill(); NSBezierPath(ovalIn:NSRect(x:x-18,y:y+96,width:36,height:34)).fill()
                let line = NSBezierPath(); line.move(to:NSPoint(x:x-10,y:y+110))
                line.curve(to:NSPoint(x:x+10,y:y+110),controlPoint1:NSPoint(x:x-6,y:y+119),controlPoint2:NSPoint(x:x+6,y:y+119))
                ink.setStroke(); line.lineWidth = 2.6; line.lineCapStyle = .round; line.stroke()
            }
        } else if action == .attack {
            stroke([NSPoint(x:95,y:y+132),NSPoint(x:112,y:y+125)],width:3,color:ink)
            stroke([NSPoint(x:144,y:y+125),NSPoint(x:161,y:y+132)],width:3,color:ink)
        } else if action == .surprised {
            paper.setFill(); NSBezierPath(ovalIn:NSRect(x:115,y:y+79,width:27,height:33)).fill()
            ink.setFill(); NSBezierPath(ovalIn:NSRect(x:122,y:y+84,width:13,height:21)).fill()
        }
    }
    func weapon(phase: Double) {
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState(); context.translateBy(x:117+CGFloat(sin(phase*2 * .pi))*13,y:111)
        context.rotate(by:.pi/2+CGFloat(sin(phase*2 * .pi))*0.05)
        ItemArtwork.draw(.sasumata,in:NSRect(x:-48,y:-148,width:96,height:296))
        context.restoreGState()
    }
    func action(_ action: HachiwareAction, phase: Double) -> NSBitmapImageRep {
        let attack = action == .attack, y: CGFloat = action == .pickup ? 39:42
        return RosterNativeRig.bitmap(NSSize(width:attack ? 440:256,height:256)) {
            let context = NSGraphicsContext.current!.cgContext
            if attack { context.translateBy(x:120,y:0) }
            drawTail(.front,y:y,phase:phase)
            for x: CGFloat in [111,145] { drawFoot(x:x,y:22,angle:0,rear:false) }
            bodies[.front]!.draw(in:bodyRect(.front,y:y)); face(action,y:y)
            let swing = CGFloat(sin(phase*2 * .pi)), left = root(.front,y:y,right:false), right = root(.front,y:y,right:true)
            var a: CGFloat = 0.05, b: CGFloat = -0.05
            switch action {
            case .wave: a = -2.1+swing*0.25
            case .laugh: a = -1.7+swing*0.10; b = 1.7-swing*0.10
            case .surprised: a = -1.1; b = 1.1
            case .pickup: a = -0.65*CGFloat(sin(.pi*phase)); b = -a
            case .camera: a = 0.55; b = -0.55
            case .guitar: a = 0.5+swing*0.12; b = -0.8
            case .sasumata: b = -0.3
            case .study: a = 0.5; b = -0.5+swing*0.05
            case .eat: a = 0.8; b = -0.8+swing*0.16
            case .vomit: a = -0.35; b = 0.35
            case .attack: a = -1.25+swing*0.08; b = -1.65+swing*0.08; weapon(phase:phase)
            }
            drawArm(at:left,angle:a,right:false); drawArm(at:right,angle:b,right:true)
            switch action {
            case .camera:
                ItemArtwork.draw(.camera,in:NSRect(x:62,y:55,width:132,height:112),strap:false)
                if phase < 0.16 { FriendArtwork.spark(149,120,size:9) }
            case .guitar:
                ItemArtwork.draw(.guitar,in:NSRect(x:45,y:36,width:180,height:140))
                ("♪" as NSString).draw(at:NSPoint(x:207,y:137+12*swing),withAttributes:[.font:NSFont.systemFont(ofSize:24),.foregroundColor:Friend.hachiware.color])
            case .sasumata: ItemArtwork.drawEquipped(.sasumata,in:NSRect(origin:.zero,size:Self.canvas),pose:.front,facing:-1,time:phase,behind:false)
            case .study:
                ActivitySpotArtwork.draw(.desk,in:NSRect(x:38,y:0,width:180,height:149))
                stroke([NSPoint(x:169,y:103),NSPoint(x:178+swing*3,y:126)],width:4,color:NSColor(hex:0xCB765C))
            case .eat:
                ActivitySpotArtwork.draw(.rice,in:NSRect(x:65,y:21,width:126,height:126))
                stroke([NSPoint(x:159,y:107+swing*8),NSPoint(x:139,y:133+swing*4)],width:2.5,color:NSColor(hex:0xA47750))
            case .vomit:
                let length = 28+82*CGFloat(pow(sin(.pi*phase),2)), stream = NSBezierPath()
                stream.move(to:NSPoint(x:122,y:138)); stream.line(to:NSPoint(x:117,y:138-length))
                stream.curve(to:NSPoint(x:139,y:138-length),controlPoint1:NSPoint(x:106,y:127-length),controlPoint2:NSPoint(x:151,y:127-length))
                stream.line(to:NSPoint(x:134,y:138)); stream.close()
                NSColor(hex:0xE7DCC6).setFill(); stream.fill(); ink.setStroke(); stream.lineWidth = 2; stream.stroke()
            default: break
            }
        }
    }
    func sleep(phase: Double) -> NSBitmapImageRep {
        RosterNativeRig.bitmap(Self.sleepCanvas) {
            let scale = min(240/sleeper.size.width,152/sleeper.size.height)
            sleeper.draw(in:NSRect(x:(256-sleeper.size.width*scale)/2,y:12,width:sleeper.size.width*scale,
                                  height:sleeper.size.height*scale+1.6*CGFloat((1-cos(phase*2 * .pi))/2)))
        }
    }
}

final class HachiwareMonsterSprites {
    static let shared = HachiwareMonsterSprites()
    static let walkFrames = 24, actionFrames = 12
    var walks: [ChiikawaDirection: [NSImage]] = [:]
    var actions: [HachiwareAction: [NSImage]] = [:]
    var sleeping: [NSImage] = []
    private(set) var registration: AttackRegistration?
    private(set) var usesBundledAtlases = false
    var isReady: Bool {
        ChiikawaDirection.allCases.allSatisfy { walks[$0]?.count == 24 }
            && HachiwareAction.allCases.allSatisfy { actions[$0]?.count == 12 } && sleeping.count == 12 && registration != nil
    }
    private init() {
        usesBundledAtlases = loadBundled()
        if !usesBundledAtlases {
            guard Bundle.main.bundleURL.pathExtension != "app", let rig = HachiwareMonsterRig() else { return }
            func image(_ rep: NSBitmapImageRep) -> NSImage { NSImage(cgImage:rep.cgImage!,size:NSSize(width:rep.pixelsWide,height:rep.pixelsHigh)) }
            func mirror(_ source: NSImage) -> NSImage {
                image(RosterNativeRig.bitmap(source.size) {
                    let c = NSGraphicsContext.current!.cgContext; c.translateBy(x:source.size.width,y:0); c.scaleBy(x:-1,y:1)
                    source.draw(in:NSRect(origin:.zero,size:source.size))
                })
            }
            for (pose, left, right) in [(HachiwarePose.front,ChiikawaDirection.down,nil),(.back,.up,nil),(.side,.left,.right),(.frontDiagonal,.downLeft,.downRight),(.backDiagonal,.upLeft,.upRight)] as [(HachiwarePose,ChiikawaDirection,ChiikawaDirection?)] {
                let cycle = (0..<24).map { image(rig.walk(pose,phase:Double($0)/24)) }
                walks[left] = cycle; if let right { walks[right] = cycle.map(mirror) }
            }
            for action in HachiwareAction.allCases { actions[action] = (0..<12).map { image(rig.action(action,phase:Double($0)/12)) } }
            sleeping = (0..<12).map { image(rig.sleep(phase:Double($0)/12)) }
        }
        let reference = AttackBodyMetrics(head:NSRect(x:58,y:42,width:140,height:194),feet:22,
            alpha:NSRect(x:0,y:0,width:256,height:256),size:NSSize(width:256,height:256))
        let attack = AttackBodyMetrics(head:reference.head.offsetBy(dx:120,dy:0),feet:22,
            alpha:NSRect(x:0,y:0,width:440,height:256),size:NSSize(width:440,height:256))
        registration = AttackRegistration(referenceMetrics:reference,frames:Array(repeating:attack,count:12))
    }
    private func loadBundled() -> Bool {
        guard Bundle.main.bundleURL.pathExtension == "app", let root = Bundle.main.resourceURL?.appendingPathComponent("Monster") else { return false }
        func load(_ name: String, count: Int, size: NSSize) -> [NSImage]? {
            guard let data = try? Data(contentsOf:root.appendingPathComponent(name+".png")),
                  let rep = NSBitmapImageRep(data:data), let atlas = rep.decodedArtwork,
                  atlas.width == Int(size.width)*6, atlas.height == Int(size.height)*count/6 else { return nil }
            return (0..<count).compactMap {
                atlas.cropping(to:CGRect(x:CGFloat($0%6)*size.width,y:CGFloat($0/6)*size.height,width:size.width,height:size.height))
                    .map { NSImage(cgImage:$0,size:size) }
            }
        }
        var walks: [ChiikawaDirection:[NSImage]] = [:], actions: [HachiwareAction:[NSImage]] = [:]
        for direction in ChiikawaDirection.allCases {
            guard let cycle = load("walk-\(direction.rawValue)-24",count:24,size:NSSize(width:256,height:256)), cycle.count == 24 else { return false }
            walks[direction] = cycle
        }
        for action in HachiwareAction.allCases {
            guard let cycle = load("action-\(action.rawValue)-12",count:12,size:NSSize(width:action == .attack ? 440:256,height:256)), cycle.count == 12 else { return false }
            actions[action] = cycle
        }
        guard let sleep = load("sleep-12",count:12,size:HachiwareMonsterRig.sleepCanvas), sleep.count == 12 else { return false }
        self.walks = walks; self.actions = actions; sleeping = sleep
        return true
    }
    static func actionIndex(_ action: HachiwareAction, time: Double) -> Int {
        let duration = action == .attack ? WeaponAttackSprites.cycleDuration : action.cycleDuration
        return HachiwareSprites.frameIndex(phase:max(0,time)/duration*2 * .pi,count:12)
    }
    func draw(in rect: NSRect, time: Double, happy: Bool = false, walking: Bool = false,
              facing: CGFloat = -1, phase: Double = 0, pose: HachiwarePose = .front,
              action: HachiwareAction? = nil, equipped: CompanionItem? = nil, actionTime: Double? = nil) {
        guard isReady else { return }
        let selected = action ?? (happy ? .wave : nil), shownPose = walking && selected == nil ? pose:.front
        let index = selected.map { Self.actionIndex($0,time:actionTime ?? time) }
            ?? (walking ? HachiwareSprites.frameIndex(phase:phase,count:24):0)
        let frame = selected.flatMap { actions[$0]?[index] }
            ?? walks[ChiikawaDirection.resolve(pose:shownPose,facing:facing)]![index]
        NSGraphicsContext.current?.imageInterpolation = .high
        if selected == .attack, let registration { frame.draw(in:registration.destination(frame:index,in:rect)); return }
        let length = min(rect.width,rect.height), destination = NSRect(x:rect.midX-length/2,y:rect.midY-length/2,width:length,height:length)
        let itemPose = selected == nil ? shownPose:.front, itemFacing: CGFloat = selected == nil ? facing:-1
        let ownsItem = [.camera,.guitar,.sasumata].contains(selected)
        let showItem = equipped != nil && !ownsItem && selected?.isDaily != true
        if showItem, let equipped { ItemArtwork.drawEquipped(equipped,in:destination,pose:itemPose,facing:itemFacing,time:time,behind:true) }
        frame.draw(in:destination)
        if showItem, let equipped { ItemArtwork.drawEquipped(equipped,in:destination,pose:itemPose,facing:itemFacing,time:time,behind:false) }
    }
    func drawSleep(in rect: NSRect, time: Double) {
        guard sleeping.count == 12 else { return }
        let index = HachiwareSprites.frameIndex(phase:max(0,time)/3.6*2 * .pi,count:12)
        let scale = min(rect.width/256,rect.height/180)
        sleeping[index].draw(in:NSRect(x:rect.midX-128*scale,y:rect.midY-90*scale,width:256*scale,height:180*scale))
    }
}
