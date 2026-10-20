import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func runHomeTests(desktop: DesktopController, now: Date, check: (Bool, String) -> Void) {
        let screen = NSRect(x: -1920, y: 65, width: 1920, height: 990)
        let frame = HomeGeometry.frame(in: screen)
        check(frame.midX == screen.midX && frame.minY == screen.minY + 12 && screen.contains(frame),
              "home stays centered just above the Dock on a negative-coordinate display")
        let small = NSRect(x: 0, y: 0, width: 300, height: 180)
        check(small.contains(HomeGeometry.frame(in: small)), "home fits within a small usable display")
        check(HomeGeometry.hit(HomeGeometry.entrance(in: frame), in: frame)
              && !HomeGeometry.hit(NSPoint(x: frame.minX + 1, y: frame.maxY - 1), in: frame),
              "house entrance is clickable while transparent upper corners pass through")
        var routine = HomeRoutine(now: now)
        check(!routine.shouldReturn(now: now.addingTimeInterval(89), automatic: true, roaming: true)
              && routine.shouldReturn(now: now.addingTimeInterval(90), automatic: true, roaming: true)
              && !routine.shouldReturn(now: now.addingTimeInterval(91), automatic: false, roaming: true)
              && !routine.shouldReturn(now: now.addingTimeInterval(91), automatic: true, roaming: false),
              "automatic rest honors its interval and both automatic-rest and walking preferences")
        routine.request(now: now)
        let door = HomeGeometry.entrance(in: frame)
        check(routine.phase == .returning && !routine.isInside
              && !routine.arrive(contact: NSPoint(x: door.x + 120, y: door.y), entrance: door, now: now),
              "requesting rest starts a journey and cannot equip the bed from a distance")
        check(routine.arrive(contact: door, entrance: door, now: now) && routine.phase == .entering,
              "reaching the actual doorway starts the entry animation")
        routine.advance(now: now.addingTimeInterval(0.8))
        check(routine.phase == .entering, "entry animation finishes before sleeping begins")
        let asleepAt = now.addingTimeInterval(HomeRoutine.entryDuration)
        routine.advance(now: asleepAt)
        check(routine.phase == .sleeping && !routine.shouldWake(now: asleepAt.addingTimeInterval(19.9))
              && routine.shouldWake(now: asleepAt.addingTimeInterval(20)),
              "sleep lasts twenty seconds after entry, then permits automatic waking")
        routine.wake(now: asleepAt)
        check(!routine.isInside && !routine.arrive(contact: door, entrance: door, now: asleepAt.addingTimeInterval(1)),
              "waking has a doorway cooldown so the character can leave the house")
        routine.request(now: asleepAt)
        check(routine.arrive(contact: door, entrance: door, now: asleepAt),
              "a deliberate house click can return home during the automatic-entry cooldown")
        check(HomeArtwork.shared.isReady
              && HomeArtwork.breathingScale(time: 0.9) > HomeArtwork.breathingScale(time: 2.7),
              "cave and sleeping reference sprites load and the breathing motion changes over time")
        check(desktop.home.panel.level == DesktopLayer.character && desktop.home.panel.level.rawValue < NSWindow.Level.normal.rawValue
              && !desktop.home.panel.canBecomeKey && desktop.home.panel.collectionBehavior == DesktopLayer.collection,
              "home stays behind normal apps, above desktop icons, without taking keyboard focus")

        let actor = desktop.actors[0]
        let initialHomeFrame = desktop.home.panel.frame
        desktop.state.homeEnabled = true
        desktop.goHome(now: now)
        check(desktop.homeRoutine.phase == .returning && !desktop.enterHomeIfReached(actor, now: now),
              "controller home action walks toward the entrance instead of teleporting")
        actor.view.onDragStart?()
        check(desktop.homeRoutine.phase == .outside, "dragging the character cancels its homeward route")
        // Keep other props stationary while a carried camera is left beside the house.
        let stationary = desktop.itemWorld.ground
        actor.panel.setFrameOrigin(ItemWorld.destination(for: desktop.home.entrance))
        desktop.goHome(now: now)
        actor.view.isDragging = true
        check(!desktop.enterHomeIfReached(actor, now: now), "dragging across the doorway never hides the character mid-drag")
        actor.view.isDragging = false
        check(desktop.enterHomeIfReached(actor, now: now)
              && desktop.homeRoutine.isInside && desktop.state.resting && desktop.itemWorld.equipped == nil
              && desktop.itemWorld.ground[.camera] != nil
              && stationary.allSatisfy { desktop.itemWorld.ground[$0.key] == $0.value },
              "dropping at the entrance enters bed and puts down only the carried prop")
        check(desktop.home.panel.frame == initialHomeFrame,
              "moving the character and entering bed never changes the house coordinates")
        let afterSleepGround = desktop.itemWorld.ground
        desktop.wakeFromHome(now: now)
        check(!desktop.homeRoutine.isInside && !desktop.state.resting
              && desktop.itemWorld.ground == afterSleepGround
              && !desktop.enterHomeIfReached(actor, now: now.addingTimeInterval(0.1)),
              "wake restores the character at the doorway without shifting props or instantly sleeping again")
        actor.view.onDragEnd?()
        check(desktop.homeRoutine.isInside,
              "deliberately dragging the character into the house overrides automatic-entry cooldown")
        desktop.seekItem(.guitar)
        check(!desktop.homeRoutine.isInside && desktop.itemWorld.requested == .guitar,
              "requesting a prop wakes the character and keeps the pickup interaction")
        desktop.goHome(now: now)
        _ = desktop.enterHomeIfReached(actor, now: now)
        desktop.home.view.onActivate?()
        check(!desktop.homeRoutine.isInside && !desktop.state.resting,
              "clicking the sleeping house wakes the character without an external connection")
        actor.dismissBubble()
        desktop.state.homeEnabled = false; desktop.state.automaticRest = false
        let saved = AppState(defaults: desktop.state.defaults)
        check(!saved.homeEnabled && !saved.automaticRest,
              "home and rest choices persist independently of other prop preferences")
        actor.panel.orderOut(nil); desktop.home.panel.orderOut(nil)
    }

    static func renderHome(to directory: URL) {
        png(width: 960, height: 620, to: directory.appendingPathComponent("hachiware-cave-home-v11.png")) {
            NSColor(hex: 0xE7E5DC).setFill(); NSRect(x: 0, y: 0, width: 960, height: 620).fill()
            HomeArtwork.shared.draw(in: NSRect(x: 120, y: 130, width: 720, height: 428), phase: .sleeping, elapsed: 2, time: 0.9)
            ("하치와레 집 · 입구에 도착하면 새근새근" as NSString).draw(at: NSPoint(x: 230, y: 65),
                withAttributes: [.font: NSFont.systemFont(ofSize: 23, weight: .medium), .foregroundColor: FriendArtwork.ink])
        }
        let count = 72
        guard let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent("hachiware-home-sleep-v11.gif") as CFURL,
            UTType.gif.identifier as CFString, count, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for index in 0..<count {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 720, pixelsHigh: 428, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 2880, bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: bitmap)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            NSColor(hex: 0xE7E5DC).setFill(); NSRect(x: 0, y: 0, width: 720, height: 428).fill()
            let time = Double(index) / 10
            HomeArtwork.shared.draw(in: NSRect(x: 0, y: 0, width: 720, height: 428),
                                    phase: index < 9 ? .entering : .sleeping, elapsed: time, time: time)
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(destination, bitmap.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }
}
