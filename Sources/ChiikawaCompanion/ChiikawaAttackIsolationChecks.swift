import AppKit

extension SelfTest {
    static func runChiikawaAttackIsolationChecks(check: (Bool, String) -> Void) {
        func bitmap(_ size: NSSize, draw: () -> Void) -> NSBitmapImageRep {
            let width = Int(size.width), height = Int(size.height)
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: width * 4, bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            context.cgContext.clear(CGRect(origin: .zero, size: size)); draw()
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            return rep
        }
        func pixels(_ rep: NSBitmapImageRep) -> Data { Data(bytes: rep.bitmapData!, count: rep.bytesPerRow * rep.pixelsHigh) }
        let view = DesktopFriendView(friend: .chiikawa)
        let cleared = bitmap(view.bounds.size) {
            view.happy = true; view.chiikawaReaction = .happy; view.draw(view.bounds)
            view.action = .attack; view.attackUsesOverlay = true; view.draw(view.bounds)
        }
        check((0..<cleared.pixelsHigh).allSatisfy { y in
            (0..<cleared.pixelsWide).allSatisfy { x in (cleared.colorAt(x: x, y: y)?.alphaComponent ?? 1) < 0.001 }
        }, "switching to the attack overlay clears the previously drawn happy body from the actor buffer")
        let overlay = AttackOverlayView(friend: .chiikawa)
        overlay.setFrameSize(NSSize(width: 300, height: 220)); overlay.body = NSRect(x: 100, y: 25, width: 132, height: 150)
        let reused = bitmap(overlay.bounds.size) {
            overlay.time = 0.01; overlay.draw(overlay.bounds)
            overlay.time = 0.61; overlay.draw(overlay.bounds)
        }
        let fresh = bitmap(overlay.bounds.size) { overlay.time = 0.61; overlay.draw(overlay.bounds) }
        check(pixels(reused) == pixels(fresh), "an attack frame replaces its previous drawing without leaving another pose underneath")
        let plain = bitmap(NSSize(width: 256, height: 256)) {
            FriendArtwork.draw(.chiikawa, in: NSRect(x: 0, y: 0, width: 256, height: 256), action: .attack, actionTime: 0.61)
        }
        let competing = bitmap(NSSize(width: 256, height: 256)) {
            FriendArtwork.draw(.chiikawa, in: NSRect(x: 0, y: 0, width: 256, height: 256), time: 3.85,
                happy: true, walking: true, action: .attack, actionTime: 0.61,
                chiikawaReaction: .happy, chiikawaItem: .pinkSasumata, chiikawaLife: .study,
                previousChiikawaReaction: .crying, reactionProgress: 0.4)
        }
        check(pixels(plain) == pixels(competing), "the attack renderer exclusively draws attack even if other animation inputs are stale")

        let suite = "ChiikawaAttackIsolationChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        state.roaming = false; state.expressive = true
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.automaticActivities = false; state.chiikawaAutomaticActivities = false
        state.automaticRest = false; state.chiikawaAutomaticRest = false
        var voiceStarts = 0
        let voice = RecordedVoicePlayer(startPlayback: { _ in voiceStarts += 1; return true })
        let desktop = DesktopController(state: state, startTimer: false,
            recordedVoice: RecordedVoicePlayer(startPlayback: { _ in true }), chiikawaVoice: voice)
        let actor = desktop.chiikawaActor!, now = Date(), away = NSPoint(x: -10000, y: -10000)
        func tick(_ offset: Double, hover: Bool = true) {
            desktop.tick(now: now.addingTimeInterval(offset),
                pointer: hover ? NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY) : away,
                pointerCanReachCharacter: true)
        }
        defer {
            voice.stop()
            desktop.actors.forEach { $0.dismissBubble(); $0.panel.orderOut(nil); $0.attackOverlay.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil); desktop.chiikawaDesk.panel.orderOut(nil); desktop.chiikawaFood.panel.orderOut(nil)
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
        }
        tick(0)
        _ = desktop.receiveChiikawaItem(.pinkSasumata, at: NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY), now: now)
        tick(0.1)
        let origin = actor.panel.frame.origin, phase = actor.gait.phase
        var exclusive = true, chronological = true
        for index in 1...360 {
            tick(0.1 + Double(index) / 60)
            exclusive = exclusive && actor.view.action == .attack && !actor.view.happy
                && actor.view.chiikawaReaction == nil && actor.view.previousChiikawaReaction == nil
                && actor.view.chiikawaLife == nil && !actor.view.walking
                && actor.view.attackUsesOverlay && actor.attackOverlay.panel.isVisible
            chronological = chronological && abs((actor.view.actionTime ?? -1) - Double(index) / 60) < 0.00001
        }
        check(exclusive && actor.panel.frame.origin == origin && actor.gait.phase == phase,
              "six seconds of armed hover contain only attack without happy transitions, life actions or walking")
        check(chronological, "equipping a weapon while already hovered starts frame one and keeps one continuous attack clock")
        tick(6.2, hover: false)
        check(actor.view.action == nil && actor.view.previousChiikawaReaction == nil && !actor.attackOverlay.panel.isVisible,
              "leaving attack restores the character without fading in a stale smile")
        var interruptsLife = true
        for (index, action) in ChiikawaLifeAction.allCases.enumerated() {
            let offset = 10 + Double(index) * 2
            desktop.playChiikawaLife(action, now: now.addingTimeInterval(offset)); tick(offset + 0.1)
            interruptsLife = interruptsLife && actor.view.action == .attack && actor.view.chiikawaLife == nil
                && desktop.chiikawaLifeRoutine.selected == nil && actor.view.actionTime == 0
            tick(offset + 0.2, hover: false)
        }
        check(interruptsLife, "armed hover interrupts each life animation and immediately begins an exclusive attack")
        actor.say("fixture", now: now.addingTimeInterval(20), duration: 0.5)
        tick(20.1)
        check(actor.view.action == nil && actor.bubble != nil, "explicit click dialogue still takes priority over armed hover")
        tick(20.6)
        check(actor.view.action == .attack && actor.view.actionTime == 0 && actor.view.chiikawaReaction == nil,
              "after click dialogue ends, hovering resumes at attack frame one without mixing the click expression")
        check(voiceStarts == 0 && voice.player == nil, "exclusive attacks and interrupted life actions preserve click-only voice playback")
    }
}
