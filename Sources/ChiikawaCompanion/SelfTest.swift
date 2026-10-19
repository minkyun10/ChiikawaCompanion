import AppKit
import ImageIO
import UniformTypeIdentifiers

enum SelfTest {
    static func run() {
        var passed = 0
        func check(_ value: @autoclosure () -> Bool, _ name: String) {
            guard value() else { fputs("FAIL: \(name)\n", stderr); exit(1) }
            passed += 1; print("PASS: \(name)")
        }
        let assignments = [Assignment(friend: .chiikawa, sender: "테스트 친구"),
                           Assignment(friend: .hachiware, sender: "다른 친구"),
                           Assignment(friend: .usagi, sender: "숨긴 친구", enabled: false)]
        check(SenderMatcher.match("테스트 친구", in: assignments) == .chiikawa, "exact sender assignment")
        check(SenderMatcher.match(" 테스트 친구\n", in: assignments) == .chiikawa, "trim boundary whitespace")
        check(SenderMatcher.match("테스트", in: assignments) == nil, "no partial sender matching")
        check(SenderMatcher.match("숨긴 친구", in: assignments) == nil, "disabled friend does not receive alerts")
        check(SenderMatcher.match("", in: [Assignment(friend: .chiikawa)]) == nil, "empty names never match")
        let duplicate = assignments + [Assignment(friend: .momonga, sender: "테스트 친구")]
        check(SenderMatcher.match("테스트 친구", in: duplicate) == nil, "ambiguous assignments fail closed")
        check(SenderMatcher.duplicateNames(duplicate) == ["테스트 친구"], "duplicate warning uses normalized names")
        let decomposed = "테스트 친구".decomposedStringWithCanonicalMapping
        check(SenderMatcher.match(decomposed, in: assignments) == .chiikawa, "Unicode normalization")

        let fixture = KakaoNotificationParser.parse(app: "카카오톡", title: nil,
            texts: [NotificationText(text: "카카오톡"), NotificationText(text: "테스트 친구"), NotificationText(text: "안녕!")], summary: nil)
        check(fixture?.sender == "테스트 친구", "fixture: app label followed by sender")
        check(fixture?.body == "안녕!", "notification carries the preview body for transient display")
        let summary = KakaoNotificationParser.parse(app: "KakaoTalk", title: nil, texts: [], summary: "KakaoTalk, 다른 친구, 안녕!")
        check(summary?.sender == "다른 친구", "fixture: app-prefixed summary")
        check(summary?.body == "안녕!", "app-prefixed summary preserves the message body")
        let punctuated = KakaoNotificationParser.parse(app: "KakaoTalk", title: nil, texts: [],
            summary: "KakaoTalk, 테스트 친구, 안녕, 내일 만날까?\n두 번째 줄 😀")
        check(punctuated?.body == "안녕, 내일 만날까?\n두 번째 줄 😀", "commas, line breaks, and emoji in a summary remain intact")
        let multipleLines = KakaoNotificationParser.parse(app: "카카오톡", title: "테스트 친구", texts: [
            NotificationText(text: "테스트 친구"), NotificationText(text: "첫 줄"),
            NotificationText(text: "다음 줄"), NotificationText(identifier: "deliveryTime", text: "오후 3:00")], summary: nil)
        check(multipleLines?.body == "첫 줄\n다음 줄", "multi-leaf body is preserved without notification timestamps")
        let explicitBody = KakaoNotificationParser.parse(app: "카카오톡", title: "테스트 친구", texts: [
            NotificationText(identifier: "messageTitle", text: "테스트 친구"),
            NotificationText(identifier: "messageBody", text: "본문만 표시")], summary: nil)
        check(explicitBody?.body == "본문만 표시", "message-title identifiers are not included as message contents")
        let titleOnly = KakaoNotificationParser.parse(app: "카카오톡", title: "테스트 친구", texts: [], summary: nil)
        check(titleOnly?.body == nil && titleOnly?.sender == "테스트 친구", "missing previews keep sender identification without inventing content")
        let bodyOnly = KakaoNotificationParser.parse(app: "카카오톡", title: "테스트 친구", texts: [
            NotificationText(identifier: "notificationBody", text: "발신자 제목은 별도 속성")], summary: nil)
        check(bodyOnly?.body == "발신자 제목은 별도 속성", "explicit body works when the sender is available only as a title attribute")
        let display = KakaoAlertPresentation(sender: "테스트 친구", body: fixture?.body)
        check(display.title == "테스트 친구" && display.message == "안녕!", "speech bubble separates sender and received message")
        check(!display.spokenText.contains("안녕!") && display.spokenText.contains("테스트 친구"),
              "voice alerts announce the sender without reading private message text")
        check(KakaoAlertPresentation(sender: "테스트 친구", body: nil).message.contains("미리보기"),
              "missing message previews have an explicit explanation")
        let longMessage = KakaoAlertPresentation(sender: "테스트 친구", body: String(repeating: "가", count: 700))
        check(longMessage.message.count == 501 && longMessage.message.hasSuffix("…"),
              "long previews are visibly abbreviated instead of overflowing the bubble")
        check(KakaoAlertPresentation(sender: "테스트 친구", body: "샘플", demo: true).title.hasPrefix("[시연]"),
              "synthetic message previews remain clearly marked as demos")
        let bodyMention = KakaoNotificationParser.parse(app: "카카오톡", title: "모르는 사람",
            texts: [NotificationText(text: "모르는 사람"), NotificationText(text: "테스트 친구")], summary: nil)
        check(SenderMatcher.match(bodyMention!.sender, in: assignments) == nil, "sender mentioned in message body does not trigger alert")
        check(KakaoNotificationParser.parse(app: "다른 앱", title: "테스트 친구", texts: [], summary: nil) == nil,
              "notifications from other apps are rejected")
        check(KakaoNotificationParser.parse(app: "카카오톡", title: nil, texts: [], summary: "안녕") == nil,
              "unrecognized layout is rejected")
        let changed = KakaoNotificationParser.parse(app: "카카오톡", title: "테스트 친구",
            texts: [NotificationText(text: "테스트 친구"), NotificationText(text: "새 메시지")], summary: nil)!
        check(changed.fingerprint != fixture?.fingerprint, "changed notification has new fingerprint")
        var dedup = NotificationDeduplicator()
        let now = Date()
        check(dedup.fresh([fixture!], now: now).isEmpty, "existing notifications are baseline on startup")
        check(dedup.fresh([fixture!, changed], now: now.addingTimeInterval(1)) == [changed], "only new notification is emitted")
        check(dedup.fresh([changed], now: now.addingTimeInterval(2)).isEmpty, "repeated scan does not repeat alert")
        dedup.reset()
        check(dedup.fresh([changed], now: now.addingTimeInterval(3)).isEmpty, "re-enabling listener resets baseline")

        let screen = NSRect(x: -1920, y: 30, width: 1920, height: 1050)
        let clamped = DesktopGeometry.clamp(NSPoint(x: 30, y: -40), size: NSSize(width: 132, height: 150), to: screen)
        check(clamped == NSPoint(x: -132, y: 30), "desktop positions clamp to negative-coordinate screen")
        let rect = NSRect(x: 0, y: 0, width: 132, height: 150)
        check(!DesktopGeometry.hit(NSPoint(x: 1, y: 1), in: rect), "transparent margins are click-through")
        check(DesktopGeometry.hit(NSPoint(x: 66, y: 75), in: rect), "character body receives pointer")

        let icons = Int(CGWindowLevelForKey(.desktopIconWindow))
        let normal = Int(CGWindowLevelForKey(.normalWindow))
        check(DesktopLayer.character.rawValue > icons, "character is above desktop icons")
        check(DesktopLayer.character.rawValue < normal, "character stays below normal app windows")
        check(DesktopLayer.bubble.rawValue > DesktopLayer.character.rawValue && DesktopLayer.bubble.rawValue < normal,
              "speech bubble stays on desktop, below app windows")
        check(!DesktopLayer.collection.contains(.fullScreenAuxiliary), "desktop character does not join full-screen overlays")
        check(Friend.developmentRoster == [.hachiware], "only Hachiware is exposed in this development stage")

        let size = NSSize(width: 132, height: 150)
        let target = RoamingMotion.target(in: screen, size: size, xFraction: 0.9, yFraction: 0.85)
        check(target.x > screen.midX && target.y > screen.midY, "destination can reach upper-right desktop")
        let start = RoamingMotion.target(in: screen, size: size, xFraction: 0.1, yFraction: 0.1)
        var motion = RoamingMotion(destination: target)
        let first = motion.advance(from: start, dt: 1.0 / 30, bounds: screen, size: size)
        check(first.x > start.x && first.y > start.y, "walking moves in both desktop axes")
        check(motion.isWalking, "walking state follows actual movement")
        var position = first
        var stayedInBounds = true
        for _ in 0..<5000 {
            position = motion.advance(from: position, dt: 1.0 / 30, bounds: screen, size: size)
            if position != DesktopGeometry.clamp(position, size: size, to: screen) { stayedInBounds = false }
        }
        check(stayedInBounds, "long journey never crosses screen edges")
        check(hypot(position.x - target.x, position.y - target.y) <= 5.1 && motion.destination == nil,
              "arrival clears target for a new journey")
        motion.destination = start
        _ = motion.advance(from: position, dt: 1.0 / 30, bounds: screen, size: size)
        check(motion.facing == -1, "walking left turns the character left")
        let walked = motion.distanceWalked
        motion.stop()
        check(!motion.isWalking && motion.distanceWalked == walked, "hover pause stops motion without advancing gait")
        motion.retarget()
        check(motion.destination == nil && !motion.isWalking, "drag release discards previous route")
        motion.destination = target
        check(motion.advance(from: start, dt: 0, bounds: screen, size: size) == start, "zero elapsed time does not move character")

        // Simulate NSWindow rounding at both standard and Retina display resolutions.
        // The last few points of a journey must accumulate instead of being discarded.
        var roundedJourneysFinish = true
        for pixelsPerPoint: CGFloat in [1, 2] {
            let area = NSRect(x: 0, y: 0, width: 1000, height: 800)
            var rendered = NSPoint(x: 100, y: 100)
            var quantized = RoamingMotion(destination: NSPoint(x: 280.5, y: 231.5))
            for _ in 0..<1800 {
                let requested = quantized.advance(from: rendered, dt: 1.0 / 60, bounds: area, size: size)
                rendered = NSPoint(x: (requested.x * pixelsPerPoint).rounded() / pixelsPerPoint,
                                   y: (requested.y * pixelsPerPoint).rounded() / pixelsPerPoint)
                if quantized.destination == nil { break }
            }
            roundedJourneysFinish = roundedJourneysFinish && quantized.destination == nil
            quantized.destination = NSPoint(x: 600, y: 600)
            let nextStart = rendered
            for _ in 0..<60 {
                let requested = quantized.advance(from: rendered, dt: 1.0 / 60, bounds: area, size: size)
                rendered = NSPoint(x: (requested.x * pixelsPerPoint).rounded() / pixelsPerPoint,
                                   y: (requested.y * pixelsPerPoint).rounded() / pixelsPerPoint)
            }
            roundedJourneysFinish = roundedJourneysFinish && hypot(rendered.x - nextStart.x, rendered.y - nextStart.y) > 20
            quantized.stop()
            let dragged = NSPoint(x: 800, y: 600)
            let resumed = quantized.advance(from: dragged, dt: 1.0 / 60, bounds: area, size: size)
            roundedJourneysFinish = roundedJourneysFinish && hypot(resumed.x - dragged.x, resumed.y - dragged.y) < 1
        }
        check(roundedJourneysFinish, "rounded windows finish journeys, start the next route, and resume from dragged positions")

        // Reproduce short and long hovers, then leave on the very next animation update.
        // There must be no minimum greeting duration to delay either the pose or movement.
        var immediateHoverRelease = true
        for duration in [0.01, 0.1, 1.4, 2.5] {
            var resumedMotion = RoamingMotion(destination: target)
            let entry = DesktopActivity.resolve(roaming: true, hovered: true, dragging: false,
                                                 notificationUntil: .distantPast, now: now)
            resumedMotion.stop()
            let exit = DesktopActivity.resolve(roaming: true, hovered: false, dragging: false,
                                                notificationUntil: .distantPast,
                                                now: now.addingTimeInterval(duration + DesktopActivity.updateInterval))
            let resumedPosition = exit == .walking
                ? resumedMotion.advance(from: start, dt: DesktopActivity.updateInterval, bounds: screen, size: size)
                : start
            immediateHoverRelease = immediateHoverRelease && entry.reacts && !exit.reacts
                && resumedMotion.isWalking && resumedPosition != start
        }
        check(immediateHoverRelease && DesktopActivity.updateInterval < 0.1,
              "short and long hovers release reaction and resume movement within the next sub-100ms update")
        check(DesktopActivity.resolve(roaming: false, hovered: false, dragging: false,
                                      notificationUntil: .distantPast, now: now) == .idle,
              "leaving hover respects the user's paused walking preference")
        check(DesktopActivity.resolve(roaming: true, hovered: false, dragging: true,
                                      notificationUntil: .distantPast, now: now) == .dragging,
              "leaving hover does not interrupt a drag")
        let notificationEnd = now.addingTimeInterval(5)
        check(DesktopActivity.resolve(roaming: true, hovered: false, dragging: false,
                                      notificationUntil: notificationEnd, now: now.addingTimeInterval(1)).reacts,
              "notification reaction remains independent of hover release")
        check(DesktopActivity.resolve(roaming: true, hovered: false, dragging: false,
                                      notificationUntil: notificationEnd, now: notificationEnd) == .walking,
              "notification reaction ends at its own deadline")

        let suite = "local.chiikawa.companion.selftest.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suite)!
        defer { testDefaults.removePersistentDomain(forName: suite) }
        let legacy = Friend.allCases.map { Assignment(friend: $0, sender: "기존-\($0.rawValue)", enabled: false) }
        testDefaults.set(try! JSONEncoder().encode(legacy), forKey: "assignments")
        let migrated = AppState(defaults: testDefaults)
        check(migrated.activeAssignments.count == 1 && migrated.activeAssignments[0].friend == .hachiware
              && migrated.activeAssignments[0].enabled, "migration enables Hachiware alone for current UI")
        check(migrated.assignments.count == 5 && migrated.assignments.first?.sender == legacy.first?.sender,
              "migration preserves the other characters' saved mappings")
        migrated.roaming = false
        let reopened = AppState(defaults: testDefaults)
        check(!reopened.roaming, "later launches preserve the user's walking preference")

        var world = ItemWorld()
        let allItems = Set(CompanionItem.allCases)
        world.configure(enabled: allItems, bounds: screen)
        check(world.ground.count == 4 && world.equipped == nil, "four enabled props spawn on the desktop")
        check(world.ground.values.allSatisfy { ItemWorld.clamp($0, to: screen) == $0 },
              "props stay reachable on negative-coordinate displays")
        let cameraPoint = world.ground[.camera]!
        let cameraOrigin = ItemWorld.destination(for: cameraPoint)
        check(!world.pickUp(.camera, from: NSPoint(x: cameraOrigin.x + 300, y: cameraOrigin.y), bounds: screen, now: now),
              "a distant prop cannot be equipped by teleporting")
        check(world.target(from: cameraOrigin, automatic: false, now: now) == nil,
              "disabling automatic pickup still leaves props on the desktop")
        world.requested = .camera
        check(world.target(from: cameraOrigin, automatic: false, now: now) == .camera,
              "clicking a prop requests a journey even with automatic pickup off")
        check(world.target(from: cameraOrigin, automatic: true, now: now, excluding: [.camera]) == nil,
              "a requested prop is not picked up while the user is dragging it")
        check(world.pickUp(.camera, from: cameraOrigin, bounds: screen, now: now)
              && world.equipped == .camera && world.ground[.camera] == nil,
              "reaching a prop transfers it from ground to equipment")
        check(world.target(from: cameraOrigin, automatic: true, now: now.addingTimeInterval(5)) == nil,
              "new equipment is carried for a while before seeking another prop")
        let guitarOrigin = ItemWorld.destination(for: world.ground[.guitar]!)
        check(world.pickUp(.guitar, from: guitarOrigin, bounds: screen, now: now.addingTimeInterval(25))
              && world.equipped == .guitar && world.ground[.camera] != nil && world.ground.count == 3,
              "swapping equipment drops the old prop without duplicating or losing it")
        world.drop(at: NSPoint(x: 9999, y: -9999), bounds: screen, now: now.addingTimeInterval(30))
        check(world.equipped == nil && world.ground.count == 4
              && world.ground.values.allSatisfy { ItemWorld.clamp($0, to: screen) == $0 },
              "manual drops restore the ground item within reachable screen bounds")
        let dropTime = now.addingTimeInterval(30)
        check(world.target(from: guitarOrigin, automatic: true, now: dropTime.addingTimeInterval(1)) == nil,
              "a dropped item is not immediately picked up again")
        let bagOrigin = ItemWorld.destination(for: world.ground[.bag]!)
        _ = world.pickUp(.bag, from: bagOrigin, bounds: screen, now: now.addingTimeInterval(50))
        world.configure(enabled: [.camera, .guitar, .sasumata], bounds: screen)
        check(world.equipped == nil && world.ground[.bag] == nil,
              "turning off a carried prop removes it from both equipment and ground")
        world.scatter(in: screen)
        check(world.ground.count == 3 && Set(world.ground.keys) == world.enabled,
              "scattering preserves exactly one instance of every enabled prop")
        // Exercise the actual drag-release callback that previously scattered props.
        // No timer or visible windows: all preferences belong to the isolated test suite.
        _ = NSApplication.shared
        let desktop = DesktopController(state: migrated, startTimer: false)
        let actor = desktop.actors[0]
        let originalGround = desktop.itemWorld.ground
        let oldOrigin = actor.panel.frame.origin
        actor.panel.setFrameOrigin(NSPoint(x: oldOrigin.x + 95, y: oldOrigin.y + 70))
        desktop.itemWorld.requested = .camera; desktop.itemTarget = .camera
        actor.motion.destination = oldOrigin
        actor.view.onDragEnd?()
        check(actor.panel.frame.origin != oldOrigin && desktop.itemWorld.ground == originalGround,
              "dragging the character leaves every ground prop at its exact original coordinate")
        check(actor.motion.destination == nil && desktop.itemTarget == nil && desktop.itemWorld.requested == .camera,
              "drag release rebuilds the character route while preserving the requested item interaction")
        desktop.resetPositions()
        check(desktop.itemWorld.ground == originalGround,
              "calling the character back never resets or scatters ground props")
        let characterPosition = actor.panel.frame.origin
        let itemPoint = originalGround[.guitar]!
        desktop.desktopItems[.guitar]?.view.onMove?(NSPoint(x: itemPoint.x - 35, y: itemPoint.y - 35))
        check(desktop.itemWorld.ground[.guitar] != itemPoint && actor.panel.frame.origin == characterPosition
              && desktop.itemWorld.ground.filter { $0.key != .guitar } == originalGround.filter { $0.key != .guitar },
              "dragging one prop moves only that prop, independently of the character and other props")
        let fixedCamera = desktop.itemWorld.ground[.camera]!
        let originAtCamera = ItemWorld.destination(for: fixedCamera)
        check(desktop.itemWorld.pickUp(.camera, from: originAtCamera, bounds: NSScreen.main!.visibleFrame, now: now)
              && desktop.itemWorld.equipped == .camera,
              "pickup still uses the unchanged ground coordinate after moving character and props independently")
        migrated.enabledItems = [.camera, .bag]; migrated.automaticItems = false; migrated.expressive = false
        let itemPreferences = AppState(defaults: testDefaults)
        check(itemPreferences.enabledItems == [.camera, .bag] && !itemPreferences.automaticItems && !itemPreferences.expressive,
              "prop and expression choices survive relaunch without changing sender assignments")
        var performance = CompanionPerformance()
        performance.begin(.camera, now: now, pickingUp: true)
        check(performance.action(now: now) == .pickup && performance.action(now: now.addingTimeInterval(0.7)) == .camera,
              "pickup gesture precedes the equipment-specific action")
        performance.cancel(now: now.addingTimeInterval(1))
        check(performance.action(now: now.addingTimeInterval(1.01)) == nil,
              "hover or drag interrupts a prop action without a delayed reaction after leaving")
        performance.begin(.guitar, now: now, pickingUp: false)
        check(performance.action(now: now.addingTimeInterval(2.5)) == nil,
              "short equipment actions finish so the character keeps walking")
        check(HachiwareActions.shared.isReady, "all eight new reference-based expressions and gestures load")
        check(HachiwareActions.shared.frames.allSatisfy {
            guard let data = $0.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else { return false }
            return (bitmap.colorAt(x: 0, y: 0)?.alphaComponent ?? 1) < 0.02
                && (bitmap.colorAt(x: 255, y: 255)?.alphaComponent ?? 1) < 0.02
        }, "action sprites retain transparent corners")

        let sprites = HachiwareSprites.shared
        check(sprites.isReady && sprites.frames.flatMap { $0 }.count == 66, "five 12-frame walks and six greeting frames load successfully")
        check(sprites.sourceSizes.count == 4, "all four selected sprite atlases decode")
        check(sprites.sourceSizes[HachiwareSprites.assetNames[2]] == NSSize(width: 3072, height: 256),
              "approved downward diagonal frames load at their original registered size")
        var diagonalBodiesStayFixed = true
        for pose in [HachiwarePose.frontDiagonal] {
            var signatures = Set<Data>()
            for index in 0..<12 {
                guard let data = sprites.frame(pose: pose, index: index)?.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: data), let image = bitmap.cgImage,
                      let head = image.cropping(to: CGRect(x: 0, y: 0, width: 256, height: 170)),
                      let pixels = head.dataProvider?.data else { diagonalBodiesStayFixed = false; continue }
                signatures.insert(pixels as Data)
            }
            if signatures.count != 1 { diagonalBodiesStayFixed = false }
        }
        check(diagonalBodiesStayFixed, "downward diagonal head and face stay identical while the feet alternate")
        let sideToePositions: [CGFloat] = (0..<12).compactMap { index in
            guard let data = sprites.frame(pose: .side, index: index)?.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: data) else { return nil }
            var lowestRow = -1
            var toePixels: [(Int, Int)] = []
            for y in 180..<256 {
                for x in 60..<210 {
                    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                          color.alphaComponent > 0.5,
                          max(color.redComponent, color.greenComponent, color.blueComponent) < 0.4 else { continue }
                    lowestRow = max(lowestRow, y); toePixels.append((x, y))
                }
            }
            let lowest = toePixels.filter { $0.1 >= lowestRow - 2 }
            guard !lowest.isEmpty else { return nil }
            return CGFloat(lowest.reduce(0) { $0 + $1.0 }) / CGFloat(lowest.count)
        }
        let plantedStep = sideToePositions.count == 12 && (0..<6).allSatisfy {
            sideToePositions[$0 + 1] >= sideToePositions[$0] - 1
        }
        let liftedReturn = sideToePositions.count == 12 && (6..<11).allSatisfy {
            sideToePositions[$0 + 1] <= sideToePositions[$0] + 1
        }
        if !(plantedStep && liftedReturn) { print("Side foot x positions: \(sideToePositions)") }
        check(plantedStep && liftedReturn,
              "side walk advances the foot in one direction before returning instead of alternating random poses")
        check(sideToePositions.count == 12 && (0..<12).allSatisfy {
            abs(sideToePositions[($0 + 1) % 12] - sideToePositions[$0]) < 34
        }, "side walk avoids the large foot-position jumps in the source sheet, including the loop boundary")
        check(HachiwareSprites.frameIndex(phase: 0) == 0 && HachiwareSprites.frameIndex(phase: 2 * .pi) == 0,
              "walking animation loops at full gait cycle")
        check(HachiwareSprites.frameIndex(phase: -.pi / 3) == 10, "negative gait phase wraps safely")
        check((0..<12).map { HachiwareSprites.frameIndex(phase: Double($0) / 12 * 2 * .pi + 1e-8) } == Array(0..<12),
              "playback visits all twelve frames in order before looping")
        check(HachiwarePose.forVelocity(CGVector(dx: 0, dy: 40)) == .back, "walking upward uses rear art")
        check(HachiwarePose.forVelocity(CGVector(dx: 0, dy: -40)) == .front, "walking downward uses front art")
        check(HachiwarePose.forVelocity(CGVector(dx: -40, dy: 10)) == .side, "horizontal walking uses side art")
        check(HachiwarePose.forVelocity(CGVector(dx: -40, dy: 40)) == .backDiagonal
              && HachiwarePose.forVelocity(CGVector(dx: 40, dy: 40)) == .backDiagonal,
              "both upward diagonals use rear three-quarter art")
        check(HachiwarePose.forVelocity(CGVector(dx: -40, dy: -40)) == .frontDiagonal
              && HachiwarePose.forVelocity(CGVector(dx: 40, dy: -40)) == .frontDiagonal,
              "both downward diagonals use front three-quarter art")
        // Travel the same real path with different sampling and elapsed times.
        func sampledGait(distance: CGFloat, samples: Int) -> WalkingGait {
            var gait = WalkingGait()
            for sample in 0..<samples {
                gait.recordMovement(from: NSPoint(x: distance * CGFloat(sample) / CGFloat(samples), y: 0),
                                    to: NSPoint(x: distance * CGFloat(sample + 1) / CGFloat(samples), y: 0))
            }
            return gait
        }
        let cycleDistance = WalkingGait.distancePerCycle
        let fullCycle = sampledGait(distance: cycleDistance, samples: 60)
        check(abs(fullCycle.phase - 2 * .pi) < 1e-8, "configured stride advances exactly one twelve-frame cycle")
        check(abs(sampledGait(distance: cycleDistance / 2, samples: 120).phase - .pi) < 1e-8,
              "half the travel distance advances only half the gait cycle")
        check(abs(sampledGait(distance: cycleDistance, samples: 15).phase - fullCycle.phase) < 1e-8,
              "same displacement produces the same gait at different update rates")
        var diagonalGait = WalkingGait()
        diagonalGait.recordMovement(from: .zero, to: NSPoint(x: cycleDistance * 0.6, y: cycleDistance * 0.8))
        check(abs(diagonalGait.phase - fullCycle.phase) < 1e-8,
              "diagonal gait uses actual path length, not summed axis distances")
        var resumedGait = sampledGait(distance: cycleDistance / 4, samples: 10)
        let stoppedPhase = resumedGait.phase
        for _ in 0..<120 { resumedGait.recordMovement(from: .zero, to: .zero) }
        check(resumedGait.phase == stoppedPhase, "stationary and rounded-away movement never advance the gait")
        resumedGait.recordMovement(from: .zero, to: NSPoint(x: cycleDistance / 4, y: 0))
        check(abs(resumedGait.phase - .pi) < 1e-8, "walking resumes from the paused gait without restarting it")
        check(HachiwarePose.allCases.filter { $0 != .greeting }.allSatisfy { pose in
            Set((0..<12).compactMap { sprites.frame(pose: pose, index: $0)?.tiffRepresentation }).count == 12
        }, "each walk contains twelve distinct drawings rather than repeated six-frame cycles")
        check(sprites.frame(pose: .front, index: 0)?.tiffRepresentation != sprites.frame(pose: .front, index: 1)?.tiffRepresentation,
              "walk frames contain different artwork")
        var transparentCorners = true
        for pose in HachiwarePose.allCases {
            for index in 0..<pose.frameCount {
                guard let data = sprites.frame(pose: pose, index: index)?.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: data) else { transparentCorners = false; continue }
                for point in [(0, 0), (255, 0), (0, 255), (255, 255)] {
                    if (bitmap.colorAt(x: point.0, y: point.1)?.alphaComponent ?? 1) > 0.02 { transparentCorners = false }
                }
            }
        }
        check(transparentCorners, "all registered frames keep transparent corners")
        if Bundle.main.bundlePath.hasSuffix(".app") {
            check(HachiwareSprites.assetURL(named: HachiwareActions.assetName)?.path.hasPrefix(Bundle.main.resourcePath ?? "missing") == true,
                  "packaged app loads its own new expression atlas")
            check(HachiwareSprites.assetNames.allSatisfy {
                HachiwareSprites.assetURL(named: $0)?.path.hasPrefix(Bundle.main.resourcePath ?? "missing") == true
            },
                  "packaged app loads its own bundled sprite, independent of source files")
        }
        print("\(passed) checks passed. Notification parser checks use fixtures, not a live KakaoTalk delivery.")
    }

    static func png(width: Int, height: Int, to url: URL, draw: () -> Void) {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        draw()
        context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
        do { try rep.representation(using: .png, properties: [:])!.write(to: url) }
        catch { fputs("Could not write artwork: \(error)\n", stderr); exit(1) }
    }
    static func renderArtwork(to path: String) {
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { fputs("Could not create artwork directory\n", stderr); exit(1) }
        png(width: 1200, height: 500, to: directory.appendingPathComponent("friends.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 1200, height: 500).fill()
            for (index, friend) in Friend.allCases.enumerated() {
                let x = CGFloat(index) * 230 + 60
                FriendArtwork.draw(friend, in: NSRect(x: x, y: 270, width: 160, height: 180), time: 1)
                FriendArtwork.draw(friend, in: NSRect(x: x, y: 45, width: 160, height: 180), time: 1, happy: true)
                let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
                (friend.name as NSString).draw(in: NSRect(x: x - 10, y: 235, width: 180, height: 22),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                                     .foregroundColor: FriendArtwork.ink, .paragraphStyle: paragraph])
            }
        }
        png(width: 1024, height: 1024, to: directory.appendingPathComponent("icon.png")) {
            NSColor(hex: 0xF7E9DB).setFill()
            NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 206, yRadius: 206).fill()
            FriendArtwork.draw(.hachiware, in: NSRect(x: 152, y: 90, width: 720, height: 810), time: 1, happy: true)
        }
        png(width: 1000, height: 280, to: directory.appendingPathComponent("hachiware-walk.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 1000, height: 280).fill()
            for index in 0..<5 {
                FriendArtwork.draw(.hachiware, in: NSRect(x: 20 + CGFloat(index) * 195, y: 35, width: 180, height: 210),
                                   time: 1, walking: true, facing: index < 3 ? 1 : -1,
                                   walkPhase: Double(index) * .pi / 2)
            }
        }
        png(width: 1500, height: 310, to: directory.appendingPathComponent("hachiware-sprite-preview.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 1500, height: 310).fill()
            for (index, pose) in HachiwarePose.allCases.enumerated() {
                HachiwareSprites.shared.draw(in: NSRect(x: 10 + CGFloat(index) * 250, y: 35, width: 230, height: 250),
                                             time: 0.4, happy: pose == .greeting, walking: true,
                                             facing: -1, walkPhase: 1, pose: pose)
            }
        }
        renderWalkAnimation(to: directory.appendingPathComponent("hachiware-12-frame-walk.gif"))
        png(width: 1800, height: 680, to: directory.appendingPathComponent("hachiware-side-cycle.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 1800, height: 680).fill()
            for index in 0..<12 {
                let x = (index % 6) * 300 + 20, y = index < 6 ? 365 : 35
                HachiwareSprites.shared.frame(pose: .side, index: index)?.draw(
                    in: NSRect(x: x, y: y, width: 260, height: 260),
                    from: .zero, operation: .sourceOver, fraction: 1)
                let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
                (String(format: "%02d", index + 1) as NSString).draw(
                    in: NSRect(x: x, y: y - 22, width: 260, height: 24),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .medium),
                                     .foregroundColor: FriendArtwork.ink, .paragraphStyle: paragraph])
            }
        }
        print("Artwork rendered.")
        renderItems(to: directory)
    }

    static func renderItems(to directory: URL) {
        func caption(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat) {
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            (text as NSString).draw(in: NSRect(x: x, y: y, width: width, height: 25), withAttributes: [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium), .foregroundColor: FriendArtwork.ink,
                .paragraphStyle: paragraph])
        }
        png(width: 1200, height: 650, to: directory.appendingPathComponent("hachiware-expressions-v7.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 1200, height: 650).fill()
            for action in HachiwareAction.allCases {
                let x = CGFloat(action.rawValue % 4) * 300, y: CGFloat = action.rawValue < 4 ? 330 : 10
                HachiwareActions.shared.draw(action, in: NSRect(x: x + 22, y: y + 30, width: 256, height: 256), time: 0.7)
                caption(action.title, x: x, y: y + 3, width: 300)
            }
        }
        png(width: 1200, height: 1080, to: directory.appendingPathComponent("hachiware-equipped-directions-v7.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 1200, height: 1080).fill()
            let poses: [HachiwarePose] = [.front, .side, .frontDiagonal, .back, .backDiagonal]
            for (row, item) in CompanionItem.allCases.enumerated() {
                for (column, pose) in poses.enumerated() {
                    let x = CGFloat(column) * 220 + 95, y = CGFloat(3 - row) * 270 + 30
                    FriendArtwork.draw(.hachiware, in: NSRect(x: x, y: y, width: 210, height: 215), time: 0.8,
                        walking: true, facing: -1, walkPhase: 1, pose: pose, equipped: item)
                    if column == 0 { caption(item.name, x: 0, y: y + 105, width: 105) }
                }
            }
        }
        let url = directory.appendingPathComponent("hachiware-items-v7.gif")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 72, nil) else { return }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for index in 0..<72 {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 960, pixelsHigh: 340,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 3840, bitsPerPixel: 32)!
            let context = NSGraphicsContext(bitmapImageRep: bitmap)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 960, height: 340).fill()
            let time = Double(index) / 10
            for (slot, item) in CompanionItem.allCases.enumerated() {
                let x = CGFloat(slot) * 240
                caption(item.name, x: x, y: 300, width: 240)
                let action: HachiwareAction? = time < 2 ? nil : time < 2.65 ? .pickup : time < 5.1 ? item.action : nil
                let moving = action == nil
                let travel = CGFloat(time < 2 ? time * 36 : time > 5.1 ? (time - 5.1) * 36 : 72)
                let petRect = NSRect(x: x + 8 + min(travel, 86), y: 60, width: 140, height: 160)
                if time < 2 { ItemArtwork.draw(item, in: NSRect(x: x + 143, y: 84, width: 60, height: 60)) }
                FriendArtwork.draw(.hachiware, in: petRect, time: time, walking: moving, facing: 1,
                    walkPhase: Double(travel / WalkingGait.distancePerCycle) * 2 * .pi, pose: .side,
                    action: action, equipped: time >= 2 ? item : nil)
                caption(time < 2 ? "주우러 가는 중" : action == .pickup ? "쏙!" : time < 5.1 ? item.action.title : "들고 산책", x: x, y: 28, width: 240)
            }
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            CGImageDestinationAddImage(destination, bitmap.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }

    static func renderWalkAnimation(to url: URL) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 12, nil) else {
            fputs("Could not create animation preview\n", stderr); exit(1)
        }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary:
            [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let directions: [(String, HachiwarePose, CGFloat)] = [
            ("UP LEFT", .backDiagonal, -1), ("UP", .back, -1),
            ("UP RIGHT", .backDiagonal, 1), ("RIGHT", .side, 1),
            ("DOWN LEFT", .frontDiagonal, -1), ("DOWN", .front, -1),
            ("DOWN RIGHT", .frontDiagonal, 1), ("LEFT", .side, -1)
        ]
        for index in 0..<12 {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 800, pixelsHigh: 440,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 3200, bitsPerPixel: 32)!
            let graphics = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: 800, height: 440).fill()
            let phase = Double(index) / 12 * 2 * .pi + 1e-8
            for (slot, direction) in directions.enumerated() {
                let x = CGFloat(slot % 4) * 200, y = slot < 4 ? CGFloat(220) : 0
                HachiwareSprites.shared.draw(in: NSRect(x: x + 10, y: y + 20, width: 180, height: 190),
                    time: Double(index) * 0.075, happy: false, walking: true,
                    facing: direction.2, walkPhase: phase, pose: direction.1)
                let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
                (direction.0 as NSString).draw(in: NSRect(x: x, y: y + 6, width: 200, height: 18),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium),
                                     .foregroundColor: FriendArtwork.ink, .paragraphStyle: paragraph])
            }
            graphics.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            guard let image = rep.cgImage else { exit(1) }
            // Match the same distance/speed ratio as the app; GIF timing uses centiseconds.
            let totalCentiseconds = Int((RoamingMotion.previewCycleDuration * 100).rounded())
            let delay = Double((index + 1) * totalCentiseconds / 12 - index * totalCentiseconds / 12) / 100
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary:
                [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            fputs("Could not save animation preview\n", stderr); exit(1)
        }
    }
}
