import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func runDailyActionChecks(defaults: UserDefaults, check: (Bool, String) -> Void) {
        let sprites = DailyActionSprites.shared
        check(sprites.isReady && sprites.frames.values.reduce(0, { $0 + $1.count }) == 36,
              "study, eating and comic spit-up each load twelve transparent animation frames")
        check(sprites.frames.values.flatMap { $0 }.allSatisfy {
            guard let data = $0.tiffRepresentation, let rep = NSBitmapImageRep(data: data) else { return false }
            return [(0, 0), (255, 0), (0, 255), (255, 255)].allSatisfy {
                (rep.colorAt(x: $0.0, y: $0.1)?.alphaComponent ?? 1) < 0.02
            }
        }, "daily sprites retain clean transparent corners without a room background")
        check(HachiwareAction.daily.allSatisfy { action in
            (0..<12).map { DailyActionSprites.frameIndex(action, time: (Double($0) + 0.01) / 12 * action.cycleDuration) } == Array(0..<12)
                && DailyActionSprites.frameIndex(action, time: action.cycleDuration) == 0
        }, "every daily animation advances through its twelve frames chronologically before looping")
        check((sprites.frames[.study] ?? []).count == 12 && (sprites.frames[.study] ?? []).allSatisfy { image in
            guard let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data) else { return false }
            var pink = 0
            for y in 108..<127 { for x in 90..<113 {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if c.alphaComponent > 0.8 && c.redComponent > 0.7 && c.redComponent - c.greenComponent > 0.14
                    && c.blueComponent > c.greenComponent && c.blueComponent > 0.4 { pink += 1 }
            } }
            return pink >= 8
        }, "all twelve study frames retain the requested pink tongue in the central mouth region")

        let now = Date()
        var performance = DailyActionPerformance()
        performance.begin(.study, now: now)
        check(performance.action(now: now.addingTimeInterval(1)) == .study
              && performance.action(now: now.addingTimeInterval(HachiwareAction.study.duration)) == nil,
              "studying uses its own duration and finishes without leaving a permanent stopped pose")
        performance.begin(.eat, now: now); performance.begin(.vomit, now: now)
        check(performance.action(now: now) == .vomit && HachiwareAction.vomit.duration == HachiwareAction.vomit.cycleDuration,
              "a new selected action replaces the previous one and spit-up runs only once")
        performance.cancel()
        check(performance.action(now: now) == nil, "manual stop releases a daily animation immediately")

        let state = AppState(defaults: defaults)
        state.characterVoice = false; state.expressive = false
        state.homeEnabled = false; state.automaticItems = true; state.roaming = true
        let desktop = DesktopController(state: state, startTimer: false)
        let actor = desktop.actors[0]
        let ground = desktop.itemWorld.ground, origin = actor.panel.frame.origin, phase = actor.gait.phase
        let away = NSPoint(x: -10000, y: -10000)
        state.onDailyAction?(.study)
        let runStarted = actor.dailyPerformance.started
        desktop.tick(now: runStarted.addingTimeInterval(0.2), pointer: away)
        check(actor.view.action == .study && actor.view.actionTime != nil && !actor.view.walking
              && state.dailyActionRunning && actor.panel.frame.origin == origin && actor.gait.phase == phase,
              "the settings action callback pauses travel at the current position and advances a local study clock")
        desktop.tick(now: runStarted.addingTimeInterval(0.4), pointer: actor.panel.frame.midPoint)
        check(actor.view.action == .study && desktop.itemWorld.ground == ground,
              "hovering preserves an explicitly selected study animation and never moves the ground props")
        actor.view.onDailyAction?(.eat)
        check(actor.view.action == .eat, "the character menu callback starts eating directly")
        actor.view.onDragStart?()
        check(actor.dailyPerformance.selected == nil && !state.dailyActionRunning,
              "dragging interrupts the daily action immediately")
        desktop.playDailyAction(.study)
        actor.view.onClick?()
        check(actor.dailyPerformance.selected == nil && actor.bubble != nil,
              "ordinary clicks stop studying and retain the fourteen-line dialogue behavior")
        desktop.playDailyAction(.eat)
        state.onStopDailyAction?()
        check(actor.dailyPerformance.selected == nil && !state.dailyActionRunning,
              "the stop callback interrupts eating immediately")
        desktop.playDailyAction(.vomit, now: now)
        desktop.tick(now: now.addingTimeInterval(HachiwareAction.vomit.duration + 0.1), pointer: away)
        check(!state.dailyActionRunning && actor.dailyPerformance.selected == nil && actor.view.action?.isDaily != true,
              "spit-up finishes in the live update path and yields to the existing roaming behavior")
        desktop.playDailyAction(.study)
        state.showFriends = false; desktop.tick(pointer: away)
        check(!state.dailyActionRunning && actor.dailyPerformance.selected == nil,
              "hiding the character cancels its active daily action")
        actor.dismissBubble(); actor.panel.orderOut(nil); desktop.home.panel.orderOut(nil)
        desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
        if Bundle.main.bundlePath.hasSuffix(".app") {
            check(DailyActionSprites.assetNames.values.allSatisfy {
                HachiwareSprites.assetURL(named: $0)?.path.hasPrefix(Bundle.main.resourcePath ?? "missing") == true
            }, "the packaged app loads all daily animations from its own bundled files")
        }
    }

    static func renderDailyActions(to directory: URL) {
        png(width: 1200, height: 960, to: directory.appendingPathComponent("hachiware-daily-frames-v16.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 1200, height: 960).fill()
            for (row, action) in HachiwareAction.daily.enumerated() {
                for (column, frame) in [0, 3, 6, 9].enumerated() {
                    let x = column * 300, y = (2 - row) * 320
                    FriendArtwork.draw(.hachiware, in: NSRect(x: x + 22, y: y + 35, width: 256, height: 256),
                        action: action, actionTime: Double(frame) / 12 * action.cycleDuration + 0.001)
                    ("\(action.title) · \(frame + 1)" as NSString).draw(at: NSPoint(x: x + 100, y: y + 12),
                        withAttributes: [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: FriendArtwork.ink])
                }
            }
        }
        for action in HachiwareAction.daily {
            let name = DailyActionSprites.assetNames[action]!
            let url = directory.appendingPathComponent(name + ".gif")
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 24, nil) else { continue }
            CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            for index in 0..<24 {
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 440,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 1600, bitsPerPixel: 32)!
                let context = NSGraphicsContext(bitmapImageRep: rep)!
                NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
                NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 400, height: 440).fill()
                FriendArtwork.draw(.hachiware, in: NSRect(x: 40, y: 65, width: 320, height: 320), action: action,
                    actionTime: Double(index) / 24 * action.cycleDuration + 0.001)
                (action.title as NSString).draw(at: NSPoint(x: 164, y: 25),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 18), .foregroundColor: FriendArtwork.ink])
                context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
                CGImageDestinationAddImage(destination, rep.cgImage!, [kCGImagePropertyGIFDictionary:
                    [kCGImagePropertyGIFDelayTime: action.cycleDuration / 24]] as CFDictionary)
            }
            precondition(CGImageDestinationFinalize(destination))
        }
    }
}

private extension NSRect {
    var midPoint: NSPoint { NSPoint(x: midX, y: midY) }
}
