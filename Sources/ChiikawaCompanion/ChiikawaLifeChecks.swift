import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func runChiikawaLifeChecks(check: (Bool,String)->Void) {
        let art = ChiikawaLifeSprites.shared
        check(art.isReady && art.studyFrames.count == 12, "Chiikawa owns a house, sleeping/pajama/hug cutouts and twelve study frames")
        check(Set(art.studyFrames.compactMap(\.tiffRepresentation)).count == 12,
              "all twelve registered Chiikawa study frames are distinct")
        check((0..<12).map { ChiikawaLifeSprites.studyIndex(time: (Double($0)+0.01)*0.15) } == Array(0..<12)
              && ChiikawaLifeSprites.studyIndex(time: 1.8) == 0 && ChiikawaLifeSprites.studyIndex(time: .nan) == 0,
              "study is chronological, loops at 1.8 seconds and handles invalid elapsed time")
        check(ChiikawaSprites.shared.reactions.count == 5 && [.startled,.determined,.gentle].allSatisfy { ChiikawaSprites.shared.reactions[$0] != nil },
              "new startled, determined and gentle reaction poses load alongside the original two")
        let wide = NSRect(x: -1440,y: 25,width: 1440,height: 850)
        let house = HomeGeometry.frame(in: wide)
        check(wide.contains(house) && house.midX == wide.midX && house.minY == wide.minY+12,
              "the shared home retains the original cave position above the Dock on a negative-coordinate screen")
        for width: CGFloat in [800,1024,1920] {
            let bounds = NSRect(x: 0,y: 0,width: width,height: 700)
            check(bounds.contains(HomeGeometry.frame(in: bounds)), "Chiikawa home stays in a \(Int(width))-point visible frame")
        }
        var routine = ChiikawaLifeRoutine()
        let now = Date(), away = NSPoint(x: -10000,y: -10000)
        routine.begin(.study,now: now)
        check(routine.action(now: now.addingTimeInterval(8.99)) == .study && routine.action(now: now.addingTimeInterval(9)) == nil,
              "study ends on time and returns control to roaming")
        routine.begin(.hug,now: now); routine.cancel()
        check(routine.action(now: now) == nil, "life actions can be cancelled immediately")
        let suite = "ChiikawaLifeChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["pochette"],forKey: "chiikawaItems")
        let state = AppState(defaults: defaults)
        check(state.chiikawaItems == [.pochette,.houseKey,.stuffedToy], "v26 migration adds only the new key and toy, preserving old disabled props")
        state.chiikawaItems.remove(.stuffedToy)
        check(!AppState(defaults: defaults).chiikawaItems.contains(.stuffedToy), "a disabled new prop does not reappear on subsequent launches")
        state.chiikawaItems = Set(ChiikawaItem.allCases)
        state.automaticRest = false; state.automaticActivities = false
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.chiikawaAutomaticRest = false; state.chiikawaAutomaticActivities = false
        let voice = RecordedVoicePlayer(startPlayback: { _ in true })
        let chiiVoice = RecordedVoicePlayer(idleStatus: "치이카와 반응",startPlayback: { _ in true })
        let desktop = DesktopController(state: state,startTimer: false,recordedVoice: voice,chiikawaVoice: chiiVoice)
        let chii = desktop.chiikawaActor!, hachi = desktop.hachiwareActor!
        defer {
            voice.stop(); chiiVoice.stop()
            desktop.actors.forEach { $0.dismissBubble(); $0.panel.orderOut(nil) }
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil); desktop.chiikawaDesk.panel.orderOut(nil)
        }
        func tick(_ offset: Double) {
            let date = now.addingTimeInterval(offset); desktop.lastTick = date.addingTimeInterval(-1.0/60)
            desktop.tick(now: date,pointer: away,pointerCanReachCharacter: false)
        }
        tick(0)
        check(desktop.home.panel.isVisible && desktop.chiikawaDesk.panel.isVisible
              && desktop.home.panel.level == DesktopLayer.character && !desktop.home.panel.canBecomeKey,
              "the shared house and Chiikawa desk use independent nonactivating desktop-only windows")
        let originalGround = desktop.chiikawaWorld.ground, hachiGround = desktop.itemWorld.ground
        let desk = desktop.chiikawaStudyWorld.positions[.desk]!
        let start = chii.panel.frame.origin
        desktop.seekChiikawaStudy(now: now)
        tick(0.02)
        check(desktop.chiikawaStudyWorld.requested == .desk && desktop.chiikawaLifeRoutine.selected == nil
              && hypot(chii.panel.frame.minX-start.x,chii.panel.frame.minY-start.y) < 3,
              "asking to study starts a real walk rather than teleporting to the table")
        chii.panel.setFrameOrigin(ItemWorld.destination(for: desk)); tick(0.04)
        check(desktop.chiikawaLifeRoutine.selected == .study && chii.view.chiikawaLife == .study
              && !desktop.chiikawaDesk.panel.isVisible && !chii.motion.isWalking,
              "arrival starts the study loop and hides only the table already included in the pose")
        check(desktop.chiikawaWorld.ground == originalGround && desktop.itemWorld.ground == hachiGround,
              "studying never relocates either inventory")
        desktop.playDailyAction(.eat,now: now)
        chii.view.onDragStart?()
        check(desktop.chiikawaLifeRoutine.selected == nil && hachi.dailyPerformance.selected == .eat,
              "dragging Chiikawa cancels only its study and leaves Hachiware eating")
        desktop.stopDailyAction()
        desktop.chiikawaDesk.view.onMove?(NSPoint(x: desk.x-80,y: desk.y-50))
        let fixedDesk = desktop.chiikawaStudyWorld.positions[.desk]
        desktop.callFriend(.chiikawa); tick(0.06)
        check(desktop.chiikawaStudyWorld.positions[.desk] == fixedDesk && desktop.chiikawaWorld.ground == originalGround,
              "calling or dragging Chiikawa preserves the desk and all ground prop coordinates")
        state.roaming = false
        let body = NSPoint(x: chii.panel.frame.midX,y: chii.panel.frame.midY)
        check(desktop.receiveChiikawaItem(.stuffedToy,at: body,now: now.addingTimeInterval(0.1))
              && desktop.chiikawaWorld.equipped == .stuffedToy && chii.view.chiikawaLife == .hug,
              "dropping the toy directly onto a stationary Chiikawa immediately starts a hug")
        desktop.stopChiikawaLife(); desktop.dropChiikawaItem(now: now)
        desktop.playChiikawaLife(.pajamas,now: now); tick(0.2)
        check(chii.view.chiikawaLife == .pajamas && !chii.motion.isWalking, "pajama pose replaces only the selected character")
        desktop.stopChiikawaLife()
        // Move the key only; the return route must visit it before the doorway.
        let contact = ItemWorld.contactPoint(origin: chii.panel.frame.origin)
        desktop.chiikawaWorld.move(.houseKey,to: NSPoint(x: contact.x+180,y: contact.y+50),bounds: NSScreen.main!.visibleFrame)
        let key = desktop.chiikawaWorld.ground[.houseKey]!
        desktop.goChiikawaHome(now: now.addingTimeInterval(0.3)); tick(0.32)
        check(desktop.chiikawaSeekingHomeKey && desktop.chiikawaWorld.requested == .houseKey
              && desktop.chiikawaHomeRoutine.phase == .returning && !desktop.chiikawaHomeRoutine.isInside,
              "going home explicitly routes to the ground key even when automatic pickup is off")
        chii.panel.setFrameOrigin(ItemWorld.destination(for: key)); tick(0.34)
        check(desktop.chiikawaWorld.equipped == .houseKey && !desktop.chiikawaSeekingHomeKey
              && desktop.chiikawaHomeRoutine.phase == .returning,
              "picking up the key continues the same journey toward home")
        let otherGround = desktop.chiikawaWorld.ground
        chii.panel.setFrameOrigin(ItemWorld.destination(for: desktop.home.entrance)); tick(0.36)
        check(desktop.chiikawaHomeRoutine.phase == .entering && !chii.panel.isVisible && state.chiikawaResting,
              "reaching the shared door hides Chiikawa for the pajama entrance transition")
        check(desktop.chiikawaWorld.equipped == nil && desktop.chiikawaWorld.ground[.houseKey] != nil
              && otherGround.allSatisfy { desktop.chiikawaWorld.ground[$0.key] == $0.value }
              && desktop.itemWorld.ground == hachiGround,
              "entering drops only the carried key and preserves every other ground prop")
        tick(1.3)
        check(desktop.chiikawaHomeRoutine.phase == .sleeping && !chii.panel.isVisible && hachi.panel.isVisible,
              "Chiikawa sleeps in pajamas after entry while Hachiware stays active")
        let homeFrame = desktop.home.panel.frame
        tick(21.4)
        check(desktop.chiikawaHomeRoutine.phase == .outside && !state.chiikawaResting && chii.panel.isVisible
              && desktop.home.panel.frame == homeFrame,
              "twenty seconds of sleep wakes Chiikawa without moving its house")
        desktop.goChiikawaHome(now: now.addingTimeInterval(21.5))
        let returnBody = NSPoint(x: chii.panel.frame.midX,y: chii.panel.frame.midY)
        check(desktop.receiveChiikawaItem(.houseKey,at: returnBody,now: now.addingTimeInterval(21.6))
              && desktop.chiikawaHomeRoutine.phase == .returning && !desktop.chiikawaSeekingHomeKey,
              "handing over the key during a return journey continues toward home without cancelling it")
        desktop.wakeChiikawa(now: now.addingTimeInterval(21.7))
        // Test explicit wake and hiding with the same production callbacks.
        desktop.didMoveChiikawa(chii,now: now.addingTimeInterval(22))
        desktop.chiikawaHomeRoutine.request(now: now.addingTimeInterval(22))
        chii.panel.setFrameOrigin(ItemWorld.destination(for: desktop.home.entrance))
        _ = desktop.enterChiikawaHomeIfReached(chii,now: now.addingTimeInterval(22))
        state.visibleFriends.remove(.chiikawa); tick(22.1)
        check(desktop.chiikawaHomeRoutine.phase == .outside && desktop.home.panel.isVisible && !chii.panel.isVisible,
              "hiding one occupant clears only its rest routine and preserves the shared home")
        state.visibleFriends.insert(.chiikawa); tick(22.2)
        let catalog = RecordingCatalog.chiikawa
        check(catalog.isValid && catalog.speaker == "이주은" && catalog.clips.count == 4,
              "Chiikawa has four independently packaged original Korean voice clips")
        check(catalog.clips.allSatisfy { $0.duration > 0.5 && $0.duration < 3 && $0.file.hasPrefix("chiikawa-") },
              "short Chiikawa clips resolve to their own safe local resources")
        let line = RecordingCatalog.shared.clips[0]
        voice.play(line,volume: 0.3)
        desktop.sayChiikawa(now: now.addingTimeInterval(23))
        let previous = chiiVoice.currentID
        check(previous != nil && voice.currentID == line.id && chii.bubble != nil,
              "Chiikawa's voice and bubble never replace Hachiware's current player")
        desktop.sayChiikawa(now: now.addingTimeInterval(23.1))
        check(chiiVoice.currentID != previous, "Chiikawa voice selection avoids immediate repeats")
        state.chiikawaVoice = false
        check(chiiVoice.currentID == nil && voice.currentID == line.id, "muting Chiikawa stops only its own recording")
        state.chiikawaVoice = true; desktop.sayChiikawa(preview: true,now: now.addingTimeInterval(23.2))
        state.visibleFriends.remove(.chiikawa); tick(23.3)
        check(chiiVoice.currentID == nil && !desktop.chiikawaDesk.panel.isVisible && desktop.home.panel.isVisible,
              "hiding Chiikawa stops its audio and desk while preserving the shared house")
    }

    static func renderChiikawaLife(to directory: URL) {
        png(width: 1440,height: 880,to: directory.appendingPathComponent("chiikawa-life-v26.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0,y: 0,width: 1440,height: 880).fill()
            let labels = ["STUDY","PAJAMAS","HUG"]
            for (index,action) in ChiikawaLifeAction.allCases.enumerated() {
                let rect = NSRect(x: index*460+30,y: 450,width: 420,height: 390)
                _ = ChiikawaLifeSprites.shared.draw(action,in: rect,elapsed: 0.5)
                (labels[index] as NSString).draw(at: NSPoint(x: rect.midX-35,y: 425),withAttributes: [.font: NSFont.systemFont(ofSize: 20),.foregroundColor: FriendArtwork.ink])
            }
            let now = Date(timeIntervalSince1970: 1000)
            var routine = HomeRoutine(now: now)
            routine.request(now: now); _ = routine.arrive(contact: .zero,entrance: .zero,now: now)
            routine.advance(now: now.addingTimeInterval(1))
            HomeArtwork.shared.draw(in: NSRect(x: 25,y: 20,width: 600,height: 356),style: .chiikawa,occupants: [HomeOccupant(friend: .chiikawa,routine: routine)],now: now.addingTimeInterval(2),time: 2)
            for (index,reaction) in [ChiikawaReaction.startled,.determined,.gentle].enumerated() {
                FriendArtwork.draw(.chiikawa,in: NSRect(x: 680+index*245,y: 110,width: 220,height: 240),chiikawaReaction: reaction)
            }
        }
        let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent("chiikawa-study-v26.gif") as CFURL,UTType.gif.identifier as CFString,12,nil)!
        CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for index in 0..<12 {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: 340,pixelsHigh: 340,bitsPerSample: 8,samplesPerPixel: 4,
                hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: 1360,bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: bitmap)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0,y: 0,width: 340,height: 340).fill()
            _ = ChiikawaLifeSprites.shared.draw(.study,in: NSRect(x: 10,y: 10,width: 320,height: 320),elapsed: Double(index)*0.15+0.001)
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(destination,bitmap.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.15]] as CFDictionary)
        }
        CGImageDestinationFinalize(destination)
    }
}
