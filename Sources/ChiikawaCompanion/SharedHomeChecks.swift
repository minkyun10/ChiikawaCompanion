import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func runSharedHomeChecks(check: (Bool,String)->Void) {
        let suite = "SharedHomeChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "homeEnabled"); defaults.set(true, forKey: "chiikawaHomeEnabled")
        let state = AppState(defaults: defaults)
        check(state.homeStyle == .hachiware && defaults.object(forKey: "homeEnabled") == nil
              && defaults.object(forKey: "chiikawaHomeEnabled") == nil,
              "old separate home toggles migrate to one shared house with Hachiware as the default")
        state.homeStyle = .chiikawa
        check(AppState(defaults: defaults).homeStyle == .chiikawa, "the single selected home design survives relaunch")
        defaults.set("unknown-house", forKey: "homeStyle")
        check(AppState(defaults: defaults).homeStyle == .hachiware, "an unavailable saved home design falls back to Hachiware")
        state.homeStyle = .hachiware
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.automaticActivities = false; state.chiikawaAutomaticActivities = false
        state.automaticRest = false; state.chiikawaAutomaticRest = false
        state.characterVoice = false; state.chiikawaVoice = false
        let desktop = DesktopController(state: state, startTimer: false), now = Date()
        let hachi = desktop.hachiwareActor!, chii = desktop.chiikawaActor!
        let houseID = desktop.home.panel.windowNumber, fixed = desktop.home.panel.frame, door = desktop.home.entrance
        let away = NSPoint(x: -10000, y: -10000)
        func tick(_ offset: Double) { desktop.tick(now: now.addingTimeInterval(offset), pointer: away, pointerCanReachCharacter: false) }
        defer {
            desktop.actors.forEach { $0.dismissBubble(); $0.panel.orderOut(nil); $0.attackOverlay.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil); desktop.chiikawaDesk.panel.orderOut(nil)
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
        }
        tick(0)
        check(desktop.home.panel.isVisible && fixed.size == HomeGeometry.size
              && HomeGeometry.frame(in: desktop.home.panel.screen!.visibleFrame) == fixed,
              "the only house uses the original Hachiware size and anchored Dock position")
        state.visibleFriends = [.chiikawa]; tick(0.01)
        check(desktop.home.panel.isVisible && desktop.home.panel.windowNumber == houseID,
              "the shared house remains when only Chiikawa is visible")
        state.homeStyle = .chiikawa; tick(0.02)
        check(desktop.home.panel.windowNumber == houseID && desktop.home.panel.frame == fixed && desktop.home.entrance == door,
              "switching house designs reuses the same window, size, position and entrance")
        state.visibleFriends = Set(Friend.developmentRoster)
        let hachiGround = desktop.itemWorld.ground, chiiGround = desktop.chiikawaWorld.ground
        desktop.activateSharedHome(now: now.addingTimeInterval(0.03))
        check(desktop.homeRoutine.phase == .returning && desktop.chiikawaHomeRoutine.phase == .returning,
              "clicking the empty shared house invites both visible friends")
        // A deliberate drop at the doorway bypasses the optional key detour.
        hachi.panel.setFrameOrigin(ItemWorld.destination(for: door))
        chii.panel.setFrameOrigin(ItemWorld.destination(for: door))
        chii.view.onDragEnd?()
        _ = desktop.enterHomeIfReached(hachi, now: now.addingTimeInterval(0.04))
        tick(1.1)
        check(desktop.homeRoutine.phase == .sleeping && desktop.chiikawaHomeRoutine.phase == .sleeping
              && !hachi.panel.isVisible && !chii.panel.isVisible && desktop.homeOccupants.count == 2,
              "Hachiware and Chiikawa sleep together in the Chiikawa design of the same house")
        let phases = desktop.homeRoutines.mapValues(\.phaseStarted)
        state.homeStyle = .hachiware; tick(1.2)
        check(desktop.homeOccupants.count == 2 && desktop.homeRoutines.mapValues(\.phaseStarted) == phases
              && desktop.home.panel.frame == fixed && desktop.home.view.style == .hachiware,
              "changing the design while sleeping preserves both occupants and their sleep clocks")
        check(desktop.itemWorld.ground == hachiGround && desktop.chiikawaWorld.ground == chiiGround,
              "sharing or switching the home never relocates either friend's ground inventory")
        desktop.activateSharedHome(now: now.addingTimeInterval(1.3)); tick(1.31)
        check(!desktop.homeRoutine.isInside && !desktop.chiikawaHomeRoutine.isInside
              && hachi.panel.isVisible && chii.panel.isVisible && desktop.homeOccupants.isEmpty,
              "clicking the occupied shared house wakes all sleepers without creating another house")
        chii.panel.setFrameOrigin(ItemWorld.destination(for: door))
        desktop.didMoveChiikawa(chii, now: now.addingTimeInterval(2)); tick(3)
        check(desktop.chiikawaHomeRoutine.isInside && desktop.home.view.occupants.contains { $0.friend == .chiikawa },
              "Chiikawa can enter and sleep in the default Hachiware design")
        state.visibleFriends.remove(.hachiware); tick(3.1)
        check(desktop.chiikawaHomeRoutine.isInside && desktop.home.panel.isVisible,
              "hiding Hachiware never evicts Chiikawa from the shared Hachiware house")
        state.showFriends = false; tick(3.2)
        check(!desktop.home.panel.isVisible && desktop.homeOccupants.isEmpty && !desktop.chiikawaHomeRoutine.isInside,
              "global hide clears sleepers and hides the single desktop home safely")
        state.showFriends = true; tick(3.3)
        check(desktop.home.panel.isVisible && desktop.home.panel.windowNumber == houseID && desktop.home.panel.frame == fixed,
              "showing friends restores exactly the same anchored home window")
    }

    static func renderSharedHome(to directory: URL) {
        let now = Date(timeIntervalSince1970: 1000)
        func occupants(at time: Double) -> [HomeOccupant] {
            Friend.developmentRoster.map { friend in
                var routine = HomeRoutine(now: now)
                routine.request(now: now); _ = routine.arrive(contact: .zero, entrance: .zero, now: now)
                routine.advance(now: now.addingTimeInterval(time))
                return HomeOccupant(friend: friend, routine: routine)
            }
        }
        png(width: 1280, height: 860, to: directory.appendingPathComponent("shared-home-designs-v29.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 1280, height: 860).fill()
            for (column, style) in HomeStyle.allCases.enumerated() {
                for row in 0..<2 {
                    let rect = NSRect(x: 40+column*640, y: 55+row*410, width: 560, height: 333)
                    HomeArtwork.shared.draw(in: rect, style: style, occupants: row == 0 ? occupants(at: 2) : [],
                                            now: now.addingTimeInterval(2), time: 2)
                    ("\(style.title) · \(row == 0 ? "함께 자기" : "공용 집 디자인")" as NSString)
                        .draw(at: NSPoint(x: rect.minX+110, y: rect.minY-25), withAttributes:
                            [.font: NSFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: FriendArtwork.ink])
                }
            }
        }
        guard let gif = CGImageDestinationCreateWithURL(directory.appendingPathComponent("shared-home-sleep-v29.gif") as CFURL,
                                                        UTType.gif.identifier as CFString, 48, nil) else { return }
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for index in 0..<48 {
            let time = Double(index)*0.1
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 960, pixelsHigh: 330, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 3840, bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 960, height: 330).fill()
            for (column, style) in HomeStyle.allCases.enumerated() {
                HomeArtwork.shared.draw(in: NSRect(x: CGFloat(column*480+15), y: 25, width: 450, height: 267.5), style: style,
                                        occupants: occupants(at: time), now: now.addingTimeInterval(time), time: time)
            }
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(gif, rep.cgImage!, [kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
        }
        CGImageDestinationFinalize(gif)
    }
}
