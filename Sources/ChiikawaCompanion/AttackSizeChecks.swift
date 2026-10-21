import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func runAttackSizeChecks(check: (Bool,String)->Void) {
        let body = NSRect(x: 0,y: 0,width: 132,height: 150)
        for (name,images,registration) in [
            ("Hachiware",WeaponAttackSprites.shared.frames,WeaponAttackSprites.shared.registration),
            ("Chiikawa",ChiikawaAttackSprites.shared.frames,ChiikawaAttackSprites.shared.registration)
        ] {
            guard let r = registration else { check(false,"\(name) attack body registration loads"); continue }
            let extent = r.extent(in: body), local = body.offsetBy(dx: -extent.minX,dy: -extent.minY)
            let expectedWidth = r.reference.head.width*132/256
            var widths: [CGFloat] = [], centers: [CGFloat] = [], feet: [CGFloat] = []
            var unclipped = true
            for index in 0..<12 {
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: Int(extent.width),pixelsHigh: Int(extent.height),
                    bitsPerSample: 8,samplesPerPixel: 4,hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,
                    bytesPerRow: Int(extent.width)*4,bitsPerPixel: 32)!
                let context = NSGraphicsContext(bitmapImageRep: bitmap)!
                NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
                NSGraphicsContext.current?.imageInterpolation = .high
                images[index].draw(in: r.destination(frame: index,in: local))
                context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
                if let metrics = AttackBodyMetrics.measure(NSImage(cgImage: bitmap.cgImage!,size: extent.size)) {
                    widths.append(metrics.head.width); centers.append(metrics.head.midX+extent.minX)
                    feet.append(metrics.feet+extent.minY)
                }
                for x in 0..<bitmap.pixelsWide {
                    unclipped = unclipped && (bitmap.colorAt(x: x,y: 0)?.alphaComponent ?? 1) < 0.02
                        && (bitmap.colorAt(x: x,y: bitmap.pixelsHigh-1)?.alphaComponent ?? 1) < 0.02
                }
                for y in 0..<bitmap.pixelsHigh {
                    unclipped = unclipped && (bitmap.colorAt(x: 0,y: y)?.alphaComponent ?? 1) < 0.02
                        && (bitmap.colorAt(x: bitmap.pixelsWide-1,y: y)?.alphaComponent ?? 1) < 0.02
                }
            }
            check(widths.count == 12 && widths.allSatisfy { abs($0-expectedWidth) <= 2 },
                  "\(name) all twelve rendered attack heads match the actual walking head within two pixels")
            check(centers.allSatisfy { abs($0-r.reference.head.midX*132/256) <= 2 },
                  "\(name) attack keeps the same body center instead of centering the long weapon")
            let expectedFeet = (150-132)/2+r.reference.feet*132/256
            check(feet.allSatisfy { abs($0-expectedFeet) <= 2 },
                  "\(name) attack feet stay on the walking baseline (expected \(expectedFeet), measured \(feet))")
            check(extent.contains(body) && extent.width > body.width && unclipped,
                  "\(name) wider attack viewport preserves the entire spear in every frame")
        }
        let suite = "AttackSizeChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        state.homeEnabled = false; state.chiikawaHomeEnabled = false
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.automaticActivities = false; state.chiikawaAutomaticActivities = false
        state.characterVoice = false; state.chiikawaVoice = false
        let desktop = DesktopController(state: state,startTimer: false), now = Date()
        let away = NSPoint(x: -10000,y: -10000)
        defer {
            desktop.actors.forEach { $0.dismissBubble(); $0.panel.orderOut(nil); $0.attackOverlay.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil); desktop.chiikawaHome.panel.orderOut(nil); desktop.chiikawaDesk.panel.orderOut(nil)
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
        }
        desktop.tick(now: now,pointer: away,pointerCanReachCharacter: true)
        for (offset,actor) in desktop.actors.enumerated() {
            let time = now.addingTimeInterval(Double(offset)*2)
            let pointer = NSPoint(x: actor.panel.frame.midX,y: actor.panel.frame.midY)
            if actor.friend == .hachiware { _ = desktop.receiveDroppedItem(.sasumata,at: pointer,now: time) }
            else { _ = desktop.receiveChiikawaItem(.pinkSasumata,at: pointer,now: time) }
            let before = actor.panel.frame, ground = desktop.itemWorld.ground, other = desktop.chiikawaWorld.ground
            desktop.tick(now: time.addingTimeInterval(0.1),pointer: pointer,pointerCanReachCharacter: true)
            let overlay = actor.attackOverlay
            check(overlay.panel.isVisible && actor.view.attackUsesOverlay && actor.panel.frame == before,
                  "\(actor.friend.name) armed hover expands only its artwork viewport, preserving the actor frame")
            check(overlay.panel.ignoresMouseEvents && !overlay.panel.canBecomeKey && overlay.panel.level == DesktopLayer.character,
                  "\(actor.friend.name) long weapon is click-through and remains behind normal apps")
            check(desktop.itemWorld.ground == ground && desktop.chiikawaWorld.ground == other,
                  "\(actor.friend.name) size correction never moves either inventory")
            desktop.tick(now: time.addingTimeInterval(0.1+DesktopActivity.updateInterval),pointer: away,pointerCanReachCharacter: true)
            check(!overlay.panel.isVisible && !actor.view.attackUsesOverlay && actor.view.action != .attack,
                  "\(actor.friend.name) leaving hover removes the expanded drawing on the next frame")
        }
    }

    static func renderAttackSizeComparison(to directory: URL) {
        func draw(index: Int) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0,y: 0,width: 1560,height: 800).fill()
            for (row,friend) in [Friend.hachiware,.chiikawa].enumerated() {
                let y = (1-row)*400
                for (col,title) in ["WALKING","BEFORE","AFTER"].enumerated() {
                    let body = NSRect(x: col*520+160,y: y+70,width: 256,height: 280)
                    if col == 0 { FriendArtwork.draw(friend,in: body,walking: true,facing: -1,walkPhase: 0,pose: .front) }
                    else if col == 1 {
                        let images = friend == .hachiware ? WeaponAttackSprites.shared.frames : ChiikawaAttackSprites.shared.frames
                        images[index].draw(in: NSRect(x: body.minX,y: body.midY-128,width: 256,height: 256))
                    } else {
                        FriendArtwork.draw(friend,in: body,action: .attack,actionTime: Double(index)*0.1+0.001)
                    }
                    (title as NSString).draw(at: NSPoint(x: col*520+205,y: y+30),withAttributes:
                        [.font:NSFont.systemFont(ofSize: 18,weight: .semibold),.foregroundColor:FriendArtwork.ink])
                }
            }
        }
        png(width: 1560,height: 800,to: directory.appendingPathComponent("weapon-hover-size-v27.png")) { draw(index: 0) }
        let gif = CGImageDestinationCreateWithURL(directory.appendingPathComponent("weapon-hover-size-v27.gif") as CFURL,UTType.gif.identifier as CFString,12,nil)!
        CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for index in 0..<12 {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: 1560,pixelsHigh: 800,bitsPerSample: 8,samplesPerPixel: 4,
                hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: 6240,bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            draw(index: index); context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(gif,rep.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
        }
        CGImageDestinationFinalize(gif)
        let report = ["hachiware":WeaponAttackSprites.shared.registration!,"chiikawa":ChiikawaAttackSprites.shared.registration!]
            .mapValues { r in ["walking_body_width":r.reference.head.width,"attack_body_widths":r.frames.map(\.head.width),
                              "scale_factors":r.frames.map { r.reference.head.width/$0.head.width }] as [String:Any] }
        try? JSONSerialization.data(withJSONObject: report,options: [.prettyPrinted,.sortedKeys])
            .write(to: directory.appendingPathComponent("body-measurements.json"))
    }
}
