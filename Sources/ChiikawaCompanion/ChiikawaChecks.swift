import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func runChiikawaChecks(defaults _: UserDefaults, check: (Bool, String) -> Void) {
        let suite = "ChiikawaChecks-\(UUID().uuidString)", now = Date(), away = NSPoint(x: -10000, y: -10000)
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        check(state.visibleFriends == Set(Friend.developmentRoster) && state.walkingFriends == Set(Friend.developmentRoster),
              "existing installations start with both companions visible and walking")
        state.automaticItems = false; state.automaticActivities = false; state.automaticRest = false;
        state.chiikawaAutomaticItems = false
        state.chiikawaAutomaticRest = false
        state.chiikawaAutomaticActivities = false; state.chiikawaVoice = false
        let voice = RecordedVoicePlayer(startPlayback: { _ in true })
        let desktop = DesktopController(state: state, startTimer: false, recordedVoice: voice)
        let hachi = desktop.hachiwareActor!, chii = desktop.chiikawaActor!
        defer {
            for actor in desktop.actors { actor.dismissBubble(); actor.panel.orderOut(nil) }
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil)
        }
        func tick(_ offset: TimeInterval, pointer: NSPoint? = nil) {
            let date = now.addingTimeInterval(offset); desktop.lastTick = date.addingTimeInterval(-1.0 / 60)
            desktop.tick(now: date, pointer: pointer ?? away, pointerCanReachCharacter: pointer != nil)
        }
        tick(0)
        check(desktop.actors.count == 2 && hachi.panel.isVisible && chii.panel.isVisible
              && chii.panel.level == DesktopLayer.character && !chii.panel.canBecomeKey,
              "two independent nonactivating character panels share the desktop-only layer")
        let sprites = ChiikawaSprites.shared
        check(sprites.isReady && sprites.frames.values.reduce(0) { $0 + $1.count } == 192,
              "Chiikawa loads eight independent 24-frame cycles plus both alpha reaction poses")
        for direction in ChiikawaDirection.allCases {
            let frames = sprites.frames[direction]!
            check(Set(frames.compactMap(\.tiffRepresentation)).count == 24,
                  "Chiikawa \(direction.rawValue) retains all 24 distinct chronological drawings")
            let url = HachiwareSprites.assetURL(named: "chiikawa-\(direction.rawValue)-24")!
            let atlas = NSBitmapImageRep(data: try! Data(contentsOf: url))!.cgImage!
            let exact = (0..<24).allSatisfy { index in
                let expected = NSImage(cgImage: atlas.cropping(to: CGRect(x: index % 6 * 256, y: index / 6 * 256, width: 256, height: 256))!,
                                       size: NSSize(width: 256, height: 256))
                return expected.tiffRepresentation == frames[index].tiffRepresentation
            }
            check(exact, "Chiikawa \(direction.rawValue) runtime frames exactly match atlas row-major order")
        }
        check(ChiikawaDirection.resolve(pose: .frontDiagonal, facing: 1) == .downRight
              && ChiikawaDirection.resolve(pose: .backDiagonal, facing: -1) == .upLeft
              && ChiikawaDirection.resolve(pose: .side, facing: -1) == .left,
              "live velocity maps to the correct front/back diagonal and side assets")
        let start = chii.panel.frame.origin, ground = desktop.chiikawaWorld.ground, hachiGround = desktop.itemWorld.ground
        chii.motion.destination = NSPoint(x: start.x + 200, y: start.y + 100)
        for i in 1...30 { tick(Double(i) / 60) }
        check(hypot(chii.panel.frame.minX - start.x, chii.panel.frame.minY - start.y) > 15 && chii.gait.phase > 0,
              "Chiikawa travels across both desktop axes and advances gait from actual displayed distance")
        let paused = chii.panel.frame.origin, phase = chii.gait.phase
        tick(0.52, pointer: NSPoint(x: chii.panel.frame.midX, y: chii.panel.frame.midY))
        check(chii.panel.frame.origin == paused && chii.gait.phase == phase && chii.view.chiikawaReaction == .happy,
              "hover pauses only Chiikawa's gait and displays the prepared happy pose")
        tick(0.54)
        check(chii.motion.isWalking && chii.view.chiikawaReaction == nil,
              "leaving Chiikawa clears the reaction and resumes walking within 20ms")
        check(desktop.chiikawaWorld.ground == ground && desktop.itemWorld.ground == hachiGround,
              "walking never moves either companion's independent ground-item coordinates")
        state.walkingFriends.remove(.chiikawa)
        let stopped = chii.panel.frame.origin, other = hachi.panel.frame.origin
        for i in 0..<20 { tick(0.56 + Double(i) / 60) }
        check(chii.panel.frame.origin == stopped && hachi.panel.frame.origin != other,
              "pausing Chiikawa preserves Hachiware's roaming")
        state.characterVoice = true
        let recorded = ClickDialogue.all.first { $0.recording != nil }!
        desktop.presentClickDialogue(recorded, for: hachi)
        let recordingID = voice.currentID, hachiBubble = hachi.bubble, lastLine = desktop.lastClickDialogueID
        chii.view.onClick?()
        check(chii.bubble != nil && voice.currentID == recordingID && hachi.bubble === hachiBubble
              && desktop.lastClickDialogueID == lastLine,
              "Chiikawa click creates its own greeting without replacing Hachiware's voice or dialogue history")
        let greeting = chii.lastGreeting; chii.view.onClick?()
        check(chii.lastGreeting != greeting, "Chiikawa greetings avoid immediate repeats")
        desktop.playDailyAction(.study)
        chii.view.onDragStart?(); chii.view.onDragEnd?()
        check(hachi.dailyPerformance.selected == .study && state.dailyActionRunning,
              "dragging Chiikawa does not cancel Hachiware's studying")
        desktop.stopDailyAction(); hachi.dismissBubble(); chii.dismissBubble()
        let fixedHachiOrigin = hachi.panel.frame.origin
        desktop.callFriend(.chiikawa)
        check(hachi.panel.frame.origin == fixedHachiOrigin && desktop.itemWorld.ground == hachiGround
              && desktop.chiikawaWorld.ground == ground,
              "calling Chiikawa resets only that character and preserves all desktop props")
        state.roaming = false; tick(1)
        let body = NSPoint(x: chii.panel.frame.midX, y: chii.panel.frame.midY)
        let hachiBody = NSPoint(x: hachi.panel.frame.midX, y: hachi.panel.frame.midY)
        check(!desktop.receiveChiikawaItem(.pochette, at: hachiBody)
              && !desktop.receiveDroppedItem(.camera, at: body),
              "a ground prop cannot be handed to the other character")
        desktop.chiikawaDesktopItems[.pochette]!.view.onMove?(body)
        desktop.chiikawaDesktopItems[.pochette]!.view.isDragging = true
        check(!desktop.receiveChiikawaItem(.pochette, at: body), "Chiikawa handoff waits until mouse release")
        desktop.chiikawaDesktopItems[.pochette]!.view.isDragging = false
        desktop.chiikawaDesktopItems[.pochette]!.view.onMoveEnd?(body)
        check(desktop.chiikawaWorld.equipped == .pochette && chii.view.chiikawaItem == .pochette
              && desktop.chiikawaWorld.ground[.pochette] == nil && !state.roaming,
              "direct drop immediately dresses Chiikawa even with walking and automatic pickup disabled")
        desktop.chiikawaDesktopItems[.pinkSasumata]!.view.onMoveEnd?(body)
        check(desktop.chiikawaWorld.equipped == .pinkSasumata && desktop.chiikawaWorld.ground[.pochette] != nil
              && desktop.chiikawaWorld.ground.count == ChiikawaItem.allCases.count-1 && desktop.itemWorld.ground == hachiGround,
              "Chiikawa item replacement drops the previous item without duplicating or moving Hachiware props")
        desktop.dropChiikawaItem(now: now)
        check(desktop.chiikawaWorld.equipped == nil && desktop.chiikawaWorld.ground.count == ChiikawaItem.allCases.count
              && desktop.chiikawaWorld.nearbyTarget(from: chii.panel.frame.origin, automatic: true, now: now) == nil,
              "putting down a Chiikawa item preserves ground coordinates and applies re-pickup cooldown")
        desktop.goHome(now: now)
        check(!desktop.enterHomeIfReached(chii, now: now), "the Hachiware entry handler cannot change the separate Chiikawa rest clock")
        hachi.panel.setFrameOrigin(ItemWorld.destination(for: desktop.home.entrance))
        check(desktop.enterHomeIfReached(hachi, now: now), "Hachiware still reaches and enters its own home")
        state.roaming = true; state.walkingFriends.insert(.chiikawa)
        tick(2)
        check(!hachi.panel.isVisible && chii.panel.isVisible && chii.motion.isWalking && desktop.homeRoutine.isInside,
              "Hachiware sleeps in the cave while Chiikawa remains visible and keeps walking")
        chii.view.onClick?(); chii.view.onDragStart?()
        check(desktop.homeRoutine.isInside, "Chiikawa click and drag leave sleeping Hachiware asleep")
        state.visibleFriends.remove(.chiikawa); tick(2.1)
        check(!chii.panel.isVisible && chii.bubble == nil && desktop.chiikawaDesktopItems.values.allSatisfy { !$0.panel.isVisible },
              "hiding Chiikawa hides its bubble and both dedicated ground props")
        desktop.wakeFromHome(now: now); state.visibleFriends.insert(.chiikawa); state.visibleFriends.remove(.hachiware)
        chii.dismissBubble(); tick(2.2)
        check(chii.panel.isVisible && !hachi.panel.isVisible && desktop.home.panel.isVisible,
              "hiding Hachiware leaves Chiikawa and the shared house visible")
        state.chiikawaItems.remove(.pinkSasumata); tick(2.3)
        check(desktop.chiikawaWorld.ground[.pinkSasumata] == nil && !desktop.receiveChiikawaItem(.pinkSasumata, at: body),
              "disabled Chiikawa items disappear and cannot be handed over")
        state.walkingFriends = [.hachiware]; state.chiikawaAutomaticItems = true
        let restored = AppState(defaults: defaults)
        check(restored.visibleFriends == [.chiikawa] && restored.walkingFriends == [.hachiware]
              && restored.chiikawaItems == [.pochette,.houseKey,.stuffedToy] && restored.chiikawaAutomaticItems,
              "visibility, walking, Chiikawa inventory and automatic pickup preferences survive relaunch independently")
        defaults.set(["chiikawa", "usagi", "unknown"], forKey: "visibleFriends")
        check(AppState(defaults: defaults).visibleFriends == [.chiikawa], "saved roster preferences cannot expose unfinished or unknown characters")
        state.visibleFriends = Set(Friend.developmentRoster)
        state.chiikawaItems = Set(ChiikawaItem.allCases); state.chiikawaAutomaticItems = false
        let bounds = NSScreen.main!.visibleFrame
        chii.panel.setFrameOrigin(RoamingMotion.target(in: bounds, size: chii.panel.frame.size, xFraction: 0.1, yFraction: 0.35))
        tick(4)
        let contact = ItemWorld.contactPoint(origin: chii.panel.frame.origin)
        desktop.chiikawaDesktopItems[.pochette]!.view.onMove?(NSPoint(x: contact.x + 220, y: contact.y + 90))
        let otherProp = desktop.chiikawaWorld.ground[.pinkSasumata], hachiProps = desktop.itemWorld.ground
        desktop.seekChiikawaItem(.pochette)
        for index in 0..<400 {
            tick(5 + Double(index) / 60)
            if desktop.chiikawaWorld.equipped == .pochette { break }
        }
        check(desktop.chiikawaWorld.equipped == .pochette && desktop.chiikawaWorld.requested == nil
              && desktop.chiikawaWorld.ground[.pinkSasumata] == otherProp && desktop.itemWorld.ground == hachiProps,
              "clicking a distant Chiikawa prop walks to and picks it up with automatic pickup off")
        desktop.dropChiikawaItem(now: now.addingTimeInterval(12))
        state.chiikawaAutomaticItems = true
        let sameBody = ItemWorld.contactPoint(origin: chii.panel.frame.origin)
        desktop.chiikawaDesktopItems[.pinkSasumata]!.view.onMove?(sameBody)
        tick(30)
        check(desktop.chiikawaWorld.equipped == .pinkSasumata && desktop.itemWorld.ground == hachiProps,
              "Chiikawa's live loop picks up a touched prop after cooldown without altering Hachiware inventory")
        if Bundle.main.bundlePath.hasSuffix(".app") {
            check(ChiikawaDirection.allCases.allSatisfy {
                HachiwareSprites.assetURL(named: "chiikawa-\($0.rawValue)-24")?.path.hasPrefix(Bundle.main.resourcePath ?? "missing") == true
            }, "packaged Chiikawa walks load entirely from the app without Source, Downloads or network access")
        }
    }

    static func renderChiikawaReview(to directory: URL) {
        let directions: [(String, HachiwarePose, CGFloat)] = [
            ("UP LEFT", .backDiagonal, -1), ("UP", .back, -1), ("UP RIGHT", .backDiagonal, 1), ("LEFT", .side, -1),
            ("RIGHT", .side, 1), ("DOWN LEFT", .frontDiagonal, -1), ("DOWN", .front, -1), ("DOWN RIGHT", .frontDiagonal, 1)
        ]
        let height = ChiikawaItem.allCases.count*300+180
        png(width: 1600, height: height, to: directory.appendingPathComponent("chiikawa-runtime-equipment-v23.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0,y: 0,width: 1600,height: height).fill()
            for (row, item) in ChiikawaItem.allCases.enumerated() {
                for (column, direction) in directions.enumerated() {
                    let rect = NSRect(x: CGFloat(column) * 200, y: CGFloat(ChiikawaItem.allCases.count-1-row) * 300 + 170, width: 200, height: 220)
                    FriendArtwork.draw(.chiikawa, in: rect, walking: true, facing: direction.2, walkPhase: .pi / 2,
                        pose: direction.1, chiikawaItem: item)
                    (direction.0 as NSString).draw(at: NSPoint(x: rect.minX + 20, y: rect.minY - 15),
                        withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: FriendArtwork.ink])
                }
            }
            for (index, reaction) in ChiikawaReaction.allCases.enumerated() {
                FriendArtwork.draw(.chiikawa, in: NSRect(x: 280 + index * 200, y: 0, width: 160, height: 170), chiikawaReaction: reaction)
            }
        }
        let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent("chiikawa-runtime-walk-v23.gif") as CFURL,
            UTType.gif.identifier as CFString, 24, nil)!
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for index in 0..<24 {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1000, pixelsHigh: 510, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 4000, bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: bitmap)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 1000, height: 510).fill()
            for (slot, direction) in directions.enumerated() {
                let rect = NSRect(x: slot % 4 * 250 + 22, y: (1 - slot / 4) * 250 + 25, width: 200, height: 220)
                FriendArtwork.draw(.chiikawa, in: rect, walking: true, facing: direction.2,
                    walkPhase: Double(index) / 24 * 2 * .pi + 1e-8, pose: direction.1)
                (direction.0 as NSString).draw(at: NSPoint(x: rect.minX + 45, y: rect.minY - 15),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: FriendArtwork.ink])
            }
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(destination, bitmap.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: RoamingMotion.previewCycleDuration / 24]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }
}
