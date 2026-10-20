import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func runChiikawaAttackChecks(check: (Bool, String) -> Void) {
        let sprites = ChiikawaAttackSprites.shared
        check(sprites.isReady && sprites.frames.count == 12, "Chiikawa armed hover loads twelve dedicated pink-weapon frames")
        check(Set(sprites.frames.compactMap(\.tiffRepresentation)).count == 12,
              "Chiikawa attack keeps twelve distinct poses rather than rotating a still")
        check(sprites.frames.allSatisfy { image in
            guard let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else { return false }
            return [(0,0),(255,0),(0,255),(255,255)].allSatisfy { (bitmap.colorAt(x: $0.0, y: $0.1)?.alphaComponent ?? 1) < 0.02 }
        }, "Chiikawa attack alpha corners remain empty and no cave or Hachiware is included")
        check((0..<12).map { ChiikawaAttackSprites.frameIndex(time: (Double($0) + 0.01) * 0.1) } == Array(0..<12)
              && ChiikawaAttackSprites.frameIndex(time: 1.2) == 0
              && ChiikawaAttackSprites.frameIndex(time: .nan) == 0
              && ChiikawaAttackSprites.frameIndex(time: -1) == 0,
              "Chiikawa attack plays in chronological order and uses Hachiware's 1.2-second loop")
        func render(_ item: ChiikawaItem?, frame: Int) -> Data {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 1024, bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            FriendArtwork.draw(.chiikawa, in: NSRect(x: 0, y: 0, width: 256, height: 256), action: .attack,
                               actionTime: (Double(frame) + 0.01) * 0.1, chiikawaItem: item)
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            return Data(bytes: rep.bitmapData!, count: rep.bytesPerRow * rep.pixelsHigh)
        }
        check((0..<12).allSatisfy { render(.pinkSasumata, frame: $0) == render(nil, frame: $0) },
              "Chiikawa attack draws exactly one weapon without a second walking-equipment overlay")
        check(Set((0..<12).map { render(.pinkSasumata, frame: $0) }).count == 12,
              "Chiikawa's live artwork dispatch visits all twelve attack drawings")

        let suite = "ChiikawaAttackChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        state.automaticItems = false; state.chiikawaAutomaticItems = false; state.automaticActivities = false
        state.homeEnabled = false; state.automaticRest = false; state.characterVoice = false
        let desktop = DesktopController(state: state, startTimer: false)
        let actor = desktop.chiikawaActor!, hachi = desktop.hachiwareActor!, now = Date()
        let away = NSPoint(x: -10000, y: -10000)
        defer {
            desktop.actors.forEach { $0.dismissBubble(); $0.panel.orderOut(nil) }
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil)
        }
        func tick(_ offset: TimeInterval, hover: Bool = false) {
            let time = now.addingTimeInterval(offset)
            desktop.lastTick = time.addingTimeInterval(-DesktopActivity.updateInterval)
            desktop.tick(now: time, pointer: hover ? NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY) : away,
                         pointerCanReachCharacter: true)
        }
        tick(0, hover: true)
        check(actor.view.action == nil && actor.view.chiikawaReaction == .happy, "unarmed Chiikawa retains the normal happy hover")
        tick(0.1)
        let body = NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY)
        check(desktop.receiveChiikawaItem(.pinkSasumata, at: body, now: now), "pink weapon can still be handed directly to Chiikawa")
        let ground = desktop.chiikawaWorld.ground, otherGround = desktop.itemWorld.ground, life = desktop.activityWorld.positions
        let origin = actor.panel.frame.origin, phase = actor.gait.phase
        tick(0.2, hover: true)
        check(actor.view.action == .attack && actor.view.actionTime == 0 && !actor.view.walking
              && actor.view.chiikawaReaction == nil && actor.panel.frame.origin == origin && actor.gait.phase == phase,
              "armed Chiikawa immediately starts attack frame one without moving its body or gait")
        tick(0.75, hover: true)
        check(actor.view.action == .attack && abs((actor.view.actionTime ?? -1) - 0.55) < 0.00001
              && desktop.chiikawaWorld.ground == ground && desktop.itemWorld.ground == otherGround && desktop.activityWorld.positions == life,
              "holding Chiikawa hover advances a local attack clock without shifting either character's props")
        tick(0.75 + DesktopActivity.updateInterval)
        check(actor.view.action == nil && actor.view.actionTime == nil && actor.motion.isWalking
              && desktop.chiikawaWorld.equipped == .pinkSasumata,
              "leaving Chiikawa hover clears attack and resumes distance-based walking on the next 60Hz tick")
        for index in 2...5 { tick(0.75 + Double(index) * DesktopActivity.updateInterval) }
        check(actor.gait.phase > phase, "Chiikawa's normal walking gait advances again within 100ms after attacking")
        state.roaming = false; tick(1, hover: true); tick(1.05)
        check(actor.view.action == nil && !actor.view.walking, "attack release respects Chiikawa's paused walking")
        actor.view.isDragging = true; tick(1.1, hover: true)
        check(actor.view.action == nil, "dragging an armed Chiikawa suppresses the hover attack")
        actor.view.isDragging = false; tick(1.2, hover: true)
        check(actor.view.action == .attack && actor.view.actionTime == 0, "a new Chiikawa hover restarts the cycle at frame one")
        actor.view.onClick?(); tick(1.25, hover: true)
        check(actor.bubble != nil && actor.view.action == nil && actor.view.actionTime == nil,
              "Chiikawa click dialogue keeps priority over armed hover")
        actor.dismissBubble(); state.expressive = false; tick(1.3, hover: true)
        check(actor.view.action == nil && actor.view.actionTime == nil, "the shared expression switch disables Chiikawa attack")
        state.expressive = true
        _ = desktop.receiveChiikawaItem(.pochette, at: NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY), now: now)
        tick(1.4, hover: true)
        check(actor.view.action == nil && actor.view.chiikawaReaction == .happy && actor.view.chiikawaItem == .pochette,
              "equipping a pochette restores Chiikawa's ordinary happy hover")
        _ = desktop.receiveChiikawaItem(.pinkSasumata, at: NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY), now: now)
        tick(1.5, hover: true); state.chiikawaItems.remove(.pinkSasumata); tick(1.6, hover: true)
        check(actor.view.action == nil && actor.view.chiikawaItem == nil, "disabling the equipped pink weapon clears the attack immediately")
        state.chiikawaItems.insert(.pinkSasumata); tick(1.7)
        _ = desktop.receiveChiikawaItem(.pinkSasumata, at: NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY), now: now)
        desktop.playDailyAction(.study, now: now)
        let hachiPosition = hachi.panel.frame.origin
        tick(1.8, hover: true)
        check(actor.view.action == .attack && hachi.dailyPerformance.selected == .study && hachi.panel.frame.origin == hachiPosition,
              "Chiikawa attacks independently while Hachiware continues studying")
        state.visibleFriends.remove(.chiikawa); tick(1.9)
        check(!actor.panel.isVisible && actor.view.action == nil && actor.view.actionTime == nil,
              "hiding an attacking Chiikawa also clears its attack state")
        state.visibleFriends.insert(.chiikawa); tick(2, hover: true)
        check(actor.view.action == .attack && actor.view.actionTime == 0, "showing Chiikawa under the pointer starts a fresh attack clock")
        if Bundle.main.bundlePath.hasSuffix(".app") {
            check(HachiwareSprites.assetURL(named: ChiikawaAttackSprites.assetName)?.path.hasPrefix(Bundle.main.resourcePath ?? "missing") == true,
                  "the packaged app loads Chiikawa's attack from its own resources without network or Source files")
        }
    }

    static func renderChiikawaAttack(to directory: URL) {
        png(width: 1440, height: 590, to: directory.appendingPathComponent("chiikawa-attack-frames-v24.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 1440, height: 590).fill()
            for index in 0..<12 {
                let x = index % 6 * 240, y = (1 - index / 6) * 290
                FriendArtwork.draw(.chiikawa, in: NSRect(x: x, y: y + 30, width: 240, height: 250), action: .attack,
                                   actionTime: (Double(index) + 0.01) * 0.1, chiikawaItem: .pinkSasumata)
                ("\(index + 1)" as NSString).draw(at: NSPoint(x: x + 114, y: y + 12),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: FriendArtwork.ink])
            }
        }
        let url = directory.appendingPathComponent("chiikawa-hover-attack-v24.gif")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 24, nil)!
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for index in 0..<24 {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 520, pixelsHigh: 400, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 2080, bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 520, height: 400).fill()
            FriendArtwork.draw(.chiikawa, in: NSRect(x: 30, y: 10, width: 460, height: 380), action: .attack,
                               actionTime: Double(index) / 24 * 1.2 + 0.001, chiikawaItem: .pinkSasumata)
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(destination, rep.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.05]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }
}
