import AppKit

extension SelfTest {
    static func runArmedHoverChecks(check: (Bool, String) -> Void) {
        let suite = "ArmedHoverChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        state.roaming = true; state.expressive = true
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.automaticActivities = false; state.chiikawaAutomaticActivities = false
        state.automaticRest = false; state.chiikawaAutomaticRest = false
        for friend in Friend.developmentRoster where friend.isExpansion {
            state.updateOptions(friend) { $0.automaticItems=false; $0.automaticActivities=false; $0.automaticRest=false }
        }
        var voiceStarts = 0
        let desktop = DesktopController(state: state, startTimer: false,
            recordedVoice: RecordedVoicePlayer(startPlayback: { _ in voiceStarts += 1; return true }),
            chiikawaVoice: RecordedVoicePlayer(startPlayback: { _ in voiceStarts += 1; return true }),
            expansionVoice: { _ in RecordedVoicePlayer(startPlayback: { _ in voiceStarts += 1; return true }) })
        let now = Date(), away = NSPoint(x: -10000, y: -10000)
        func opaquePoints(in rect: NSRect, draw: () -> Void) -> [NSPoint] {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(rect.width), pixelsHigh: Int(rect.height),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: Int(rect.width) * 4, bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            context.cgContext.clear(NSRect(origin: .zero, size: rect.size))
            context.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
            draw(); context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            var result: [NSPoint] = []
            for y in stride(from: 0, to: rep.pixelsHigh, by: 3) { for x in stride(from: 0, to: rep.pixelsWide, by: 3) {
                if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                    result.append(NSPoint(x: rect.minX + CGFloat(x) + 0.5, y: rect.maxY - CGFloat(y) - 0.5))
                }
            } }
            return result
        }
        defer {
            desktop.actors.forEach { $0.dismissBubble(); $0.panel.orderOut(nil); $0.attackOverlay.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil); desktop.chiikawaDesk.panel.orderOut(nil); desktop.chiikawaFood.panel.orderOut(nil)
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
        }
        desktop.tick(now: now, pointer: away, pointerCanReachCharacter: true)
        for (offset, actor) in desktop.actors.enumerated() {
            let start = now.addingTimeInterval(Double(offset) * 20)
            let center = NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY)
            if let companion=desktop.expansions[actor.friend] {
                _ = companion.receive(.weapon,at:center,now:start); companion.stopAction()
            } else if actor.friend == .hachiware { _ = desktop.receiveDroppedItem(.sasumata, at: center, now: start) }
            else { _ = desktop.receiveChiikawaItem(.pinkSasumata, at: center, now: start) }
            actor.performance.cancel(now: start)
            // Find an actual opaque walking pixel that the old inset rectangle missed.
            let bounds = actor.view.bounds
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bounds.width), pixelsHigh: Int(bounds.height),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: Int(bounds.width) * 4, bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            context.cgContext.clear(bounds)
            FriendArtwork.draw(actor.friend, in: bounds, walking: true, facing: -1, walkPhase: 0, pose: .front,
                equipped: actor.friend == .hachiware ? .sasumata : nil,
                chiikawaItem: actor.friend == .chiikawa ? .pinkSasumata : nil,
                rosterVisual: actor.friend.isExpansion ? RosterVisual(equipped:.weapon) : nil)
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            let inset = bounds.insetBy(dx: bounds.width * 0.13, dy: bounds.height * 0.06)
            var missed: [NSPoint] = [], visible: [NSPoint] = []
            for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide {
                let point = NSPoint(x: CGFloat(x) + 0.5, y: bounds.height - CGFloat(y) - 0.5)
                if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.8 {
                    visible.append(point)
                    if !inset.contains(point) { missed.append(point) }
                }
            } }
            if actor.friend.isExpansion {
                // A tall canvas can contain the whole narrow rabbit inside the old
                // inset. Use a real edge pixel rather than inventing an out-of-bounds fixture.
                if missed.isEmpty { missed = visible.sorted { $0.x < $1.x }.prefix(1).map { $0 } }
                check(!missed.isEmpty, "\(actor.friend.name) armed entry fixture uses an actual visible outline pixel")
            } else {
                check(!missed.isEmpty, "\(actor.friend.name) regression fixture has visible armed pixels outside the old hover rectangle")
            }
            let point = missed[missed.count / 2]
            actor.view.walking = true; actor.view.pose = .front; actor.view.facing = -1
            let world = NSPoint(x: actor.panel.frame.minX + point.x, y: actor.panel.frame.minY + point.y)
            desktop.tick(now: start.addingTimeInterval(0.1), pointer: world, pointerCanReachCharacter: true)
            check(actor.view.action == .attack && !actor.view.walking,
                "\(actor.friend.name) visible body and carried weapon outside the old inset start attack without a walking frame")
            let attackMask = ArmedPointerArtwork.shared.attack(actor.friend)
            let completeAttack = (0..<12).allSatisfy { frame in
                let points = opaquePoints(in: attackMask.rect) {
                    FriendArtwork.draw(actor.friend, in: bounds, action: .attack, actionTime: (Double(frame) + 0.25) * 0.1)
                }
                return !points.isEmpty && points.allSatisfy(attackMask.contains)
            }
            check(completeAttack, "\(actor.friend.name) stable hover silhouette covers the actual body and spear in all twelve attack drawings")
            var allDirections = true
            for pose in HachiwarePose.allCases where pose != .greeting {
                for facing: CGFloat in pose.canMirror ? [-1, 1] : [-1] {
                    let mask = ArmedPointerArtwork.shared.walking(actor.friend, pose: pose, facing: facing)
                    for frame in [0, 3, 6, 9] {
                        let phase = (Double(frame) + 0.25) / 12 * 2 * .pi
                        let points = opaquePoints(in: bounds) {
                            FriendArtwork.draw(actor.friend, in: bounds, time: 0, walking: true, facing: facing,
                                walkPhase: phase, pose: pose, equipped: actor.friend == .hachiware ? .sasumata : nil,
                                chiikawaItem: actor.friend == .chiikawa ? .pinkSasumata : nil,
                rosterVisual: actor.friend.isExpansion ? RosterVisual(equipped:.weapon) : nil)
                        }
                        allDirections = allDirections && !points.isEmpty && points.allSatisfy(mask.contains)
                    }
                }
            }
            check(allDirections, "\(actor.friend.name) armed hover covers rendered walking outlines in all eight directions")
            var tip: NSPoint?
            for y in Int(attackMask.rect.minY)..<Int(attackMask.rect.maxY) {
                for x in Int(attackMask.rect.minX)..<Int(attackMask.rect.maxX) {
                    let sample = NSPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5)
                    if !bounds.insetBy(dx: -4, dy: -4).contains(sample) && attackMask.contains(sample) {
                        tip = sample; break
                    }
                }
                if tip != nil { break }
            }
            check(tip != nil, "\(actor.friend.name) attack fixture includes a spear outside the actor window")
            let weapon = NSPoint(x: actor.panel.frame.minX + tip!.x, y: actor.panel.frame.minY + tip!.y)
            let origin = actor.panel.frame.origin, gait = actor.gait.phase
            var stable = true
            for index in 1...360 {
                desktop.tick(now: start.addingTimeInterval(0.1 + Double(index) / 60), pointer: weapon,
                    pointerCanReachCharacter: true)
                stable = stable && actor.view.action == .attack && !actor.view.walking
                    && actor.panel.frame.origin == origin && actor.gait.phase == gait
                    && abs((actor.view.actionTime ?? -1) - Double(index) / 60) < 0.00001
            }
            check(stable, "\(actor.friend.name) six seconds on the extended weapon keep one uninterrupted attack clock and position")
            desktop.tick(now: start.addingTimeInterval(6.2), pointer: weapon, pointerCanReachCharacter: false)
            check(actor.view.action != .attack && actor.armedHoverContact == nil,
                "\(actor.friend.name) a foreground window immediately releases armed hover")
            desktop.tick(now: start.addingTimeInterval(6.3), pointer: weapon, pointerCanReachCharacter: true)
            check(actor.view.action != .attack, "\(actor.friend.name) an empty future swing area cannot start another attack")
            desktop.tick(now: start.addingTimeInterval(6.4), pointer: actor.panel.frame.center, pointerCanReachCharacter: true)
            check(actor.view.action == .attack, "\(actor.friend.name) returning to the visible body restarts attack")
            desktop.tick(now: start.addingTimeInterval(6.4 + DesktopActivity.updateInterval), pointer: away,
                pointerCanReachCharacter: true)
            check(actor.view.action != .attack && !actor.attackOverlay.panel.isVisible && actor.view.walking,
                "\(actor.friend.name) leaving the whole silhouette resumes walking in one 60Hz update")
            check(!attackMask.contains(NSPoint(x: attackMask.rect.minX, y: attackMask.rect.maxY - 0.5)),
                "\(actor.friend.name) transparent expanded corners do not retain hover")
        }
        check(voiceStarts == 0, "armed pointer regression never plays click-only voices")
        check(!DesktopPointerVisibility.canReach(actor: 3, hit: 1, frontToBack: [1, 2, 3, 4])
            && DesktopPointerVisibility.canReach(actor: 3, hit: 3, frontToBack: [1, 2, 3, 4])
            && DesktopPointerVisibility.canReach(actor: 3, hit: 4, frontToBack: [1, 2, 3, 4])
            && !DesktopPointerVisibility.canReach(actor: 3, hit: 4, frontToBack: [1, 2, 4]),
            "pointer stacking rejects foreground apps and hidden-space actors while allowing the actor and desktop behind it")

        // Exercise real WindowServer ordering without injecting pointer visibility.
        // No mouse events are synthesized and no user's app is activated.
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let probe = desktop.actors[0], oldLevel = probe.panel.level, oldFrame = probe.panel.frame
        let visible = NSScreen.main!.visibleFrame
        probe.panel.setFrameOrigin(NSPoint(x: visible.midX - 66, y: visible.midY - 75))
        probe.panel.level = .floating; probe.panel.orderFrontRegardless()
        probe.panel.displayIfNeeded()
        let pointer = probe.panel.frame.center
        let cover = FriendPanel(contentRect: NSRect(x: pointer.x - 12, y: pointer.y - 12, width: 24, height: 24),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        cover.isFloatingPanel = false; cover.ignoresMouseEvents = false
        cover.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        cover.isReleasedWhenClosed = false; cover.hidesOnDeactivate = false
        cover.collectionBehavior = DesktopLayer.collection
        cover.isOpaque = true; cover.backgroundColor = .white
        cover.contentView = OpaqueHoverProbeView(frame: NSRect(origin: .zero, size: cover.frame.size))
        defer { cover.orderOut(nil); probe.panel.level = oldLevel; probe.panel.setFrame(oldFrame, display: false) }
        probe.panel.ignoresMouseEvents = true
        let clickThrough = DesktopPointerVisibility.canReach(probe.panel, at: pointer)
        probe.panel.ignoresMouseEvents = false
        let interactive = DesktopPointerVisibility.canReach(probe.panel, at: pointer)
        check(clickThrough && interactive, "native hover visibility remains true when the actor changes its mouse-event transparency")
        cover.orderFrontRegardless()
        cover.display(); cover.contentView!.display()
        application.updateWindows()
        CATransaction.flush()
        // WindowServer input regions commit after the raster backing store is
        // painted, not merely after orderFront returns.
        let paintDeadline = Date().addingTimeInterval(1)
        while Date() < paintDeadline {
            let paintedOrder = NSWindow.windowNumbers(options: .allApplications)!.map(\.intValue)
            if DesktopPointerVisibility.hitWindow(at: pointer, frontToBack: paintedOrder) == cover.windowNumber { break }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        let order = NSWindow.windowNumbers(options: .allApplications)!.map(\.intValue)
        let nativeHit = DesktopPointerVisibility.hitWindow(at: pointer, frontToBack: order)
        print("Native hover probe: actor=\(probe.panel.windowNumber) cover=\(cover.windowNumber) hit=\(String(describing: nativeHit)) coverVisible=\(cover.isVisible) ignores=\(cover.ignoresMouseEvents) activeSpace=\(cover.isOnActiveSpace) rawHit=\(NSWindow.windowNumber(at: pointer, belowWindowWithWindowNumber: 0)) listed=\(order.contains(cover.windowNumber)) actorFrame=\(probe.panel.frame) coverFrame=\(cover.frame) point=\(pointer)")
        check(nativeHit == cover.windowNumber, "native foreground fixture receives the actual mouse-down hit test")
        check(!DesktopPointerVisibility.canReach(probe.panel, at: pointer),
            "native pointer visibility rejects a small foreground window even if the rest of the character is visible")
        cover.orderOut(nil)
        check(DesktopPointerVisibility.canReach(probe.panel, at: pointer),
            "native hover visibility recovers after uncovering without waiting for occlusion notifications")
        let oldAction = probe.view.action, oldOverlayLevel = probe.attackOverlay.panel.level
        probe.view.action = .attack; probe.attackOverlay.panel.level = .floating
        probe.attackOverlay.update(actor: probe)
        probe.view.displayIfNeeded(); probe.attackOverlay.view.displayIfNeeded()
        check(DesktopPointerVisibility.canReach(probe.panel, at: pointer),
            "native hover stays reachable when the actor buffer is transparent and the separate attack window paints its body")
        probe.view.action = oldAction; probe.attackOverlay.panel.level = oldOverlayLevel
        probe.attackOverlay.update(actor: probe)
    }
}

private extension NSRect {
    var center: NSPoint { NSPoint(x: midX, y: midY) }
}

/// A real raster backing store is required for WindowServer mouse hit testing.
/// A layer-only background may appear in the window order before it is painted.
private final class OpaqueHoverProbeView: NSView {
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) { NSColor.white.setFill(); bounds.fill() }
}
