import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func runChiikawaMotionChecks(check: (Bool,String)->Void) {
        let art = ChiikawaMotionSprites.shared
        check(art.isReady, "all five new Chiikawa animation atlases load")
        for motion in ChiikawaMotion.allCases {
            let frames = art.frames[motion] ?? []
            check(frames.count == motion.count && Set(frames.compactMap(\.tiffRepresentation)).count == motion.count,
                  "\(motion.rawValue) contains \(motion.count) distinct chronological drawings")
            check(frames.allSatisfy { image in
                guard let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data) else { return false }
                return [(0,0),(255,0),(0,255),(255,255)].allSatisfy { (rep.colorAt(x: $0.0,y: $0.1)?.alphaComponent ?? 1) < 0.02 }
            }, "\(motion.rawValue) preserves transparent sprite corners")
        }
        check((0..<12).map { ChiikawaMotionSprites.index(.eat,elapsed: (Double($0)+0.01)*0.15) } == Array(0..<12)
              && ChiikawaMotionSprites.index(.eat,elapsed: 1.8) == 0,
              "the eating cycle visits all twelve cells in order before looping")
        check(ChiikawaMotionSprites.index(.pajamas,elapsed: 3) == 11
              && ChiikawaMotionSprites.index(.pajamas,elapsed: .greatestFiniteMagnitude) == 11,
              "dressing finishes in the final clothed pose and safely holds it")
        check(ChiikawaBlinkArtwork.shared.source.count == 2 && ChiikawaBlinkArtwork.shared.target.count == 2
              && ChiikawaBlinkArtwork.blinkElapsed(time: 3.8) != nil && ChiikawaBlinkArtwork.blinkElapsed(time: 2) == nil,
              "blinks register only the two eyes and occur briefly at a controlled interval")
        // Compare the actual overlay pixels with the unchanged approved walk frame.
        func blinkBitmap(_ shown: Bool) -> NSBitmapImageRep {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: 256,pixelsHigh: 256,bitsPerSample: 8,
                samplesPerPixel: 4,hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: 1024,bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            ChiikawaSprites.shared.frames[.down]!.first!.draw(in: NSRect(x: 0,y: 0,width: 256,height: 256))
            if shown { ChiikawaBlinkArtwork.shared.draw(in: NSRect(x: 0,y: 0,width: 256,height: 256),time: 3.85) }
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState(); return rep
        }
        let open = blinkBitmap(false), closed = blinkBitmap(true)
        let before = open.bitmapData!, after = closed.bitmapData!
        var changedEyes = 0, outside = 0
        for y in 0..<256 { for x in 0..<256 {
            let i = y*1024+x*4
            if (0..<4).contains(where: { before[i+$0] != after[i+$0] }) {
                if ChiikawaBlinkArtwork.shared.target.contains(where: { $0.insetBy(dx: -1,dy: -1).contains(NSPoint(x: CGFloat(x)+0.5,y: 255.5-CGFloat(y))) }) { changedEyes += 1 }
                else { outside += 1 }
            }
        } }
        check(changedEyes > 10 && outside == 0, "blinking changes eye pixels while preserving every walking limb and body pixel")
        check(!ChiikawaLifeAction.allCases.map(\.rawValue).contains("vomit"), "Chiikawa has no vomiting action")
        let suite = "ChiikawaMotionChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.automaticRest = false; state.chiikawaAutomaticRest = false
        state.automaticActivities = false; state.chiikawaAutomaticActivities = true
        state.characterVoice = false; state.chiikawaVoice = false; state.roaming = false
        let desktop = DesktopController(state: state,startTimer: false), actor = desktop.chiikawaActor!, now = Date()
        let away = NSPoint(x: -10000,y: -10000)
        func tick(_ offset: Double) { desktop.tick(now: now.addingTimeInterval(offset),pointer: away,pointerCanReachCharacter: false) }
        defer {
            desktop.actors.forEach { $0.dismissBubble(); $0.panel.orderOut(nil); $0.attackOverlay.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil); desktop.chiikawaDesk.panel.orderOut(nil); desktop.chiikawaFood.panel.orderOut(nil)
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
        }
        tick(0)
        check(desktop.chiikawaStudyWorld.enabled == [.desk,.rice] && desktop.chiikawaFood.panel.isVisible,
              "Chiikawa owns an independent desk and food bowl, with no furball")
        let bowl = desktop.chiikawaStudyWorld.positions[.rice]!, hachiGround = desktop.itemWorld.ground, chiiGround = desktop.chiikawaWorld.ground
        actor.panel.setFrameOrigin(ItemWorld.destination(for: bowl)); tick(0.1)
        check(actor.view.chiikawaLife == .eat && !desktop.chiikawaFood.panel.isVisible && !actor.motion.isWalking,
              "entering the bowl radius starts eating and hides only the bowl included in the animation")
        check(desktop.itemWorld.ground == hachiGround && desktop.chiikawaWorld.ground == chiiGround,
              "eating keeps both characters' inventories at their existing world coordinates")
        tick(6.2)
        check(desktop.chiikawaLifeRoutine.selected == nil && desktop.chiikawaFood.panel.isVisible,
              "eating ends after six seconds and restores the same ground bowl without repeating in place")
        state.chiikawaAutomaticActivities = false
        actor.panel.setFrameOrigin(NSPoint(x: actor.panel.frame.minX-200,y: actor.panel.frame.minY+50))
        desktop.seekChiikawaFood(now: now.addingTimeInterval(6.3)); tick(6.31)
        check(desktop.chiikawaStudyWorld.requested == .rice && actor.motion.isWalking && actor.view.chiikawaLife == nil,
              "explicit food requests walk to the bowl even with automatic actions off")
        actor.panel.setFrameOrigin(ItemWorld.destination(for: bowl)); tick(6.4)
        check(actor.view.chiikawaLife == .eat, "reaching an explicitly requested bowl begins the meal")
        state.chiikawaFoodEnabled = false; tick(6.5)
        check(desktop.chiikawaLifeRoutine.selected == nil && !desktop.chiikawaFood.panel.isVisible
              && desktop.chiikawaStudyWorld.positions[.rice] == nil,
              "disabling the bowl cancels its meal and removes only that activity spot")
        check(!AppState(defaults: defaults).chiikawaFoodEnabled, "food visibility persists independently")
        desktop.goChiikawaHome(now: now.addingTimeInterval(7))
        desktop.chiikawaSeekingHomeKey = false; desktop.chiikawaWorld.requested = nil
        actor.panel.setFrameOrigin(ItemWorld.destination(for: desktop.home.entrance)); tick(7.1); tick(8.1)
        let fixed = desktop.home.panel.frame
        desktop.wakeFriend(.chiikawa,now: now.addingTimeInterval(8.2)); tick(8.3)
        check(desktop.chiikawaWakingAt != nil && !actor.panel.isVisible
              && desktop.homeOccupants.contains { $0.friend == .chiikawa && $0.wakingStarted != nil },
              "waking renders the blanket and stretching sequence inside the shared home before walking")
        tick(9.3)
        check(desktop.chiikawaWakingAt == nil && actor.panel.isVisible && !state.chiikawaResting
              && desktop.home.panel.frame == fixed,
              "finishing the wake animation restores the character without moving the house")
        desktop.playChiikawaLife(.pajamas,now: now.addingTimeInterval(10))
        actor.view.onDragStart?()
        check(desktop.chiikawaLifeRoutine.selected == nil && desktop.itemWorld.ground == hachiGround,
              "dragging interrupts the dressing sequence without touching the other character")
        actor.view.time = 20; actor.view.chiikawaReaction = .happy
        actor.view.time = 20.05; actor.view.chiikawaReaction = .crying
        check(actor.view.previousChiikawaReaction == .happy && actor.view.chiikawaReactionChanged == 20.05,
              "expression changes keep the previous pose for a local one-tenth-second transition")
    }

    static func renderChiikawaMotion(to directory: URL) {
        for mode in ["expression-transition","walking-blink"] {
            let count = mode == "walking-blink" ? 96 : 72
            let gif = CGImageDestinationCreateWithURL(directory.appendingPathComponent("chiikawa-\(mode)-v30.gif") as CFURL,UTType.gif.identifier as CFString,count,nil)!
            CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            let poses: [ChiikawaReaction?] = [nil,.happy,.crying,.startled,.determined,.gentle,nil]
            for index in 0..<count {
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: 240,pixelsHigh: 260,bitsPerSample: 8,samplesPerPixel: 4,
                    hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: 960,bitsPerPixel: 32)!
                let context = NSGraphicsContext(bitmapImageRep: rep)!
                NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
                NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0,y: 0,width: 240,height: 260).fill()
                let group = index/12, progress = min(1,Double(index%12)/2)
                FriendArtwork.draw(.chiikawa,in: NSRect(x: 10,y: 10,width: 220,height: 240),time: Double(index)*0.05,
                    walking: mode == "walking-blink",walkPhase: Double(index)*0.05/RoamingMotion.previewCycleDuration*2 * .pi,
                    pose: .front,chiikawaReaction: mode == "walking-blink" ? nil : poses[min(6,group+1)],
                    previousChiikawaReaction: mode == "walking-blink" ? nil : poses[min(5,group)],
                    reactionProgress: mode == "walking-blink" ? 1 : progress)
                context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
                CGImageDestinationAddImage(gif,rep.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.05]] as CFDictionary)
            }
            CGImageDestinationFinalize(gif)
        }
        for motion in ChiikawaMotion.allCases {
            png(width: motion.columns*256,height: ((motion.count+motion.columns-1)/motion.columns)*256,
                to: directory.appendingPathComponent("chiikawa-\(motion.rawValue)-frames-v30.png")) {
                for index in 0..<motion.count {
                    _ = ChiikawaMotionSprites.shared.draw(motion,index: index,
                        in: NSRect(x: index%motion.columns*256,y: ((motion.count-1)/motion.columns-index/motion.columns)*256,width: 256,height: 256))
                }
            }
            let gif = CGImageDestinationCreateWithURL(directory.appendingPathComponent("chiikawa-\(motion.rawValue)-v30.gif") as CFURL,
                                                       UTType.gif.identifier as CFString,48,nil)!
            CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for index in 0..<48 {
                let time = Double(index)/48*(motion == .rest ? 3.2 : motion == .blink ? 0.54 : 3.6)
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: 320,pixelsHigh: 320,bitsPerSample: 8,samplesPerPixel: 4,
                    hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: 1280,bitsPerPixel: 32)!
                let context = NSGraphicsContext(bitmapImageRep: rep)!
                NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
                NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0,y: 0,width: 320,height: 320).fill()
                let frame = motion == .rest ? min(15,Int(time/3.2*16))
                    : motion == .blink ? ChiikawaMotionSprites.index(.blink,elapsed: time.truncatingRemainder(dividingBy: 0.27))
                    : ChiikawaMotionSprites.index(motion,elapsed: time)
                _ = ChiikawaMotionSprites.shared.draw(motion,index: frame,in: NSRect(x: 10,y: 10,width: 300,height: 300))
                context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
                CGImageDestinationAddImage(gif,rep.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.075]] as CFDictionary)
            }
            CGImageDestinationFinalize(gif)
        }
    }
}
