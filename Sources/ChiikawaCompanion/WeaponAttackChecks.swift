import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func runWeaponAttackChecks(defaults: UserDefaults, check: (Bool, String) -> Void) {
        let sprites = WeaponAttackSprites.shared
        check(sprites.isReady && sprites.frames.count == 12, "weapon hover loads twelve dedicated attack frames")
        check(Set(sprites.frames.compactMap(\.tiffRepresentation)).count == 12,
              "the attack contains twelve distinct drawings rather than one rotated still")
        check(sprites.frames.allSatisfy { image in
            guard let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data) else { return false }
            return [(0,0),(255,0),(0,255),(255,255)].allSatisfy { (rep.colorAt(x:$0.0,y:$0.1)?.alphaComponent ?? 1) < 0.02 }
        }, "attack sprites retain transparent corners without the reference cave or other character")
        check((0..<12).map { WeaponAttackSprites.frameIndex(time:(Double($0)+0.01)/12*1.2) } == Array(0..<12)
              && WeaponAttackSprites.frameIndex(time:1.2) == 0
              && WeaponAttackSprites.frameIndex(time:.infinity) == 0,
              "attack playback stays chronological, loops cleanly and rejects invalid clocks")
        check([0.0,0.2,2,100].allSatisfy { HachiwareAction.hover(equipped:.sasumata,elapsed:$0) == .attack }
              && HachiwareAction.hover(equipped:nil,elapsed:0) == .wave
              && HachiwareAction.hover(equipped:.camera,elapsed:1) == .laugh
              && HachiwareAction.hover(equipped:.guitar,elapsed:1) == .laugh,
              "only a held sasumata changes the regular greeting into the determined attack")
        func renderedAttack(equipped: CompanionItem?) -> Data {
            let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:256,pixelsHigh:256,bitsPerSample:8,
                samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:1024,bitsPerPixel:32)!
            let context = NSGraphicsContext(bitmapImageRep:rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            context.cgContext.clear(NSRect(x:0,y:0,width:256,height:256))
            FriendArtwork.draw(.hachiware,in:NSRect(x:0,y:0,width:256,height:256),action:.attack,equipped:equipped,actionTime:0.55)
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            return Data(bytes:rep.bitmapData!,count:rep.bytesPerRow*rep.pixelsHigh)
        }
        check(renderedAttack(equipped:.sasumata) == renderedAttack(equipped:nil),
              "the attack already includes one weapon and never receives a duplicate equipment overlay")

        let state = AppState(defaults: defaults)
        state.enabledItems = [.sasumata,.camera]; state.automaticItems = false
        state.automaticActivities = false;
        state.characterVoice = false; state.expressive = true
        state.showFriends = true; state.roaming = true
        let desktop = DesktopController(state:state,startTimer:false), actor = desktop.actors[0]
        let away = NSPoint(x:-10000,y:-10000), now = Date()
        desktop.tick(now:now,pointer:away,pointerCanReachCharacter:true)
        let body = actor.panel.frame.attackCenter
        desktop.desktopItems[.sasumata]!.view.onMove?(body)
        _ = desktop.receiveDroppedItem(.sasumata,at:body,now:now)
        let ground = desktop.itemWorld.ground, life = desktop.activityWorld.positions
        let phase = actor.gait.phase, origin = actor.panel.frame.origin
        let area = actor.panel.screen!.visibleFrame
        actor.motion.destination = RoamingMotion.target(in:area,size:actor.panel.frame.size,xFraction:0.9,yFraction:0.8)
        desktop.tick(now:now.addingTimeInterval(0.1),pointer:body,pointerCanReachCharacter:true)
        check(actor.view.action == .attack && actor.view.actionTime == 0 && !actor.view.walking
              && actor.panel.frame.origin == origin && actor.gait.phase == phase,
              "weapon hover starts the attack immediately on a local clock without advancing travel")
        desktop.tick(now:now.addingTimeInterval(0.65),pointer:body,pointerCanReachCharacter:true)
        check(actor.view.action == .attack && abs((actor.view.actionTime ?? -1)-0.55) < 0.0001
              && desktop.itemWorld.ground == ground && desktop.activityWorld.positions == life,
              "holding hover advances the attack without moving props or replacing equipment")
        desktop.tick(now:now.addingTimeInterval(0.65+DesktopActivity.updateInterval),pointer:away,pointerCanReachCharacter:true)
        check(actor.view.action == nil && actor.view.actionTime == nil && actor.view.walking
              && desktop.itemWorld.equipped == .sasumata,
              "leaving weapon hover releases the attack and resumes the existing gait on the next sub-100ms tick")
        for step in 2...5 {
            desktop.tick(now:now.addingTimeInterval(0.65+Double(step)*DesktopActivity.updateInterval),pointer:away,pointerCanReachCharacter:true)
        }
        check(actor.gait.phase > phase, "distance-based gait resumes within 100ms even when the first resumed window position rounds to the same pixel")
        state.roaming = false
        desktop.tick(now:now.addingTimeInterval(1),pointer:actor.panel.frame.attackCenter,pointerCanReachCharacter:true)
        desktop.tick(now:now.addingTimeInterval(1.1),pointer:away,pointerCanReachCharacter:true)
        check(actor.view.action == nil && !actor.view.walking, "leaving weapon hover preserves paused walking")
        actor.view.isDragging = true
        desktop.tick(now:now.addingTimeInterval(1.2),pointer:actor.panel.frame.attackCenter,pointerCanReachCharacter:true)
        check(actor.view.action != .attack, "dragging the armed character does not continue a hover attack")
        actor.view.isDragging = false
        desktop.tick(now:now.addingTimeInterval(1.3),pointer:actor.panel.frame.attackCenter,pointerCanReachCharacter:true)
        check(actor.view.action == .attack && actor.view.actionTime == 0, "a new weapon hover restarts at frame one")
        desktop.presentClickDialogue(ClickDialogue.all.last!,for:actor)
        desktop.tick(now:now.addingTimeInterval(1.4),pointer:actor.panel.frame.attackCenter,pointerCanReachCharacter:true)
        check(actor.view.action == .surprised && actor.view.actionTime == nil && actor.bubble != nil,
              "click dialogue retains priority over the weapon attack while hovered")
        desktop.playDailyAction(.study,now:now.addingTimeInterval(1.5))
        desktop.tick(now:now.addingTimeInterval(1.6),pointer:actor.panel.frame.attackCenter,pointerCanReachCharacter:true)
        check(actor.view.action == .study, "explicit study animation keeps priority over armed hover")
        desktop.stopDailyAction(); state.expressive = false
        desktop.tick(now:now.addingTimeInterval(1.7),pointer:actor.panel.frame.attackCenter,pointerCanReachCharacter:true)
        check(actor.view.action == nil, "the expression switch also disables the weapon hover animation")
        state.expressive = true
        _ = desktop.receiveDroppedItem(.camera,at:actor.panel.frame.attackCenter,now:now.addingTimeInterval(1.8))
        desktop.tick(now:now.addingTimeInterval(1.9),pointer:actor.panel.frame.attackCenter,pointerCanReachCharacter:true)
        check(actor.view.action == .laugh && actor.view.equipped == .camera,
              "replacing the weapon restores the normal hover greeting immediately")
        actor.dismissBubble(); actor.panel.orderOut(nil); desktop.home.panel.orderOut(nil)
        desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
        desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
        if Bundle.main.bundlePath.hasSuffix(".app") {
            check(HachiwareSprites.assetURL(named:WeaponAttackSprites.assetName)?.path.hasPrefix(Bundle.main.resourcePath ?? "missing") == true,
                  "the packaged app loads its attack sheet from its own bundled resources")
        }
    }

    static func renderWeaponAttack(to directory: URL) {
        png(width:1200,height:520,to:directory.appendingPathComponent("hachiware-attack-frames-v19.png")) {
            NSColor(hex:0xF7F4EB).setFill(); NSRect(x:0,y:0,width:1200,height:520).fill()
            for index in 0..<12 {
                let x = index%6*200, y = (1-index/6)*260
                FriendArtwork.draw(.hachiware,in:NSRect(x:x,y:y+35,width:200,height:210),action:.attack,
                                   equipped:.sasumata,actionTime:(Double(index)+0.01)/12*1.2)
                ("\(index+1)" as NSString).draw(at:NSPoint(x:x+92,y:y+12),withAttributes:
                    [.font:NSFont.systemFont(ofSize:15),.foregroundColor:FriendArtwork.ink])
            }
        }
        let url = directory.appendingPathComponent("hachiware-hover-attack-v19.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL,UTType.gif.identifier as CFString,24,nil) else { return }
        CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for index in 0..<24 {
            let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:400,pixelsHigh:360,bitsPerSample:8,
                samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:1600,bitsPerPixel:32)!
            let context = NSGraphicsContext(bitmapImageRep:rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            NSColor(hex:0xF7F4EB).setFill(); NSRect(x:0,y:0,width:400,height:360).fill()
            FriendArtwork.draw(.hachiware,in:NSRect(x:30,y:35,width:340,height:310),action:.attack,
                equipped:.sasumata,actionTime:Double(index)/24*1.2+0.001)
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(destination,rep.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.05]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }
}

private extension NSRect {
    var attackCenter: NSPoint { NSPoint(x:midX,y:midY) }
}
