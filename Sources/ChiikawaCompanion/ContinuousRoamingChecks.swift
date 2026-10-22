import AppKit

extension SelfTest {
    static func runContinuousRoamingChecks(check: (Bool, String) -> Void) {
        let suite = "ContinuousRoamingChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        state.characterVoice = false; state.chiikawaVoice = false
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.automaticRest = false; state.chiikawaAutomaticRest = false
        state.expressive = false
        let desktop = DesktopController(state: state, startTimer: false)
        let now = Date(), away = NSPoint(x: -10000, y: -10000)
        func tick(_ offset: Double) {
            let date = now.addingTimeInterval(offset)
            desktop.lastTick = date.addingTimeInterval(-DesktopActivity.updateInterval)
            desktop.tick(now: date, pointer: away, pointerCanReachCharacter: false)
        }
        defer {
            desktop.actors.forEach { $0.dismissBubble(); $0.panel.orderOut(nil); $0.attackOverlay.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil); desktop.chiikawaDesk.panel.orderOut(nil); desktop.chiikawaFood.panel.orderOut(nil)
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
        }
        guard let bounds = NSScreen.main?.visibleFrame else { check(false, "a desktop is available for continuous movement checks"); return }
        let point = ItemWorld.contactPoint(origin: RoamingMotion.target(in: bounds, size: NSSize(width: 132, height: 150), xFraction: 0.45, yFraction: 0.65))
        var continuous = true, walksLastSegment = true, arrives = true, positionsPreserved = true
        var offset = 0.0
        for friend in [Friend.hachiware, .chiikawa] {
            let actor = desktop.actors.first { $0.friend == friend }!
            let spots: [ActivitySpot] = friend == .hachiware ? [.desk, .rice, .furball] : [.desk, .rice]
            for spot in spots {
                desktop.stopDailyAction(); desktop.stopChiikawaLife()
                state.roaming = true; state.walkingFriends = [friend]
                state.automaticActivities = friend == .hachiware; state.chiikawaAutomaticActivities = friend == .chiikawa
                state.enabledActivitySpots = friend == .hachiware ? [spot] : []
                state.chiikawaStudyEnabled = friend == .chiikawa && spot == .desk
                state.chiikawaFoodEnabled = friend == .chiikawa && spot == .rice
                desktop.activityWorld = ActivitySpotWorld(); desktop.chiikawaStudyWorld = ActivitySpotWorld()
                tick(offset)
                if friend == .hachiware { desktop.activityWorld.move(spot, to: point, bounds: bounds) }
                else { desktop.chiikawaStudyWorld.move(spot, to: point, bounds: bounds) }
                let origin = ItemWorld.destination(for: point).offsetBy(dx: -28, dy: 0)
                actor.panel.setFrameOrigin(origin); actor.motion.retarget()
                actor.motion.destination = ItemWorld.destination(for: point)
                let ground = desktop.itemWorld.ground, otherGround = desktop.chiikawaWorld.ground
                let initialSpots = friend == .hachiware ? desktop.activityWorld.positions : desktop.chiikawaStudyWorld.positions
                var maxStep: CGFloat = 0, began = false
                for index in 1...360 {
                    let before = actor.panel.frame.origin
                    tick(offset + Double(index) / 60)
                    let after = actor.panel.frame.origin
                    maxStep = max(maxStep, hypot(after.x - before.x, after.y - before.y))
                    began = friend == .hachiware ? actor.dailyPerformance.selected != nil : desktop.chiikawaLifeRoutine.selected != nil
                    if index == 1 { walksLastSegment = walksLastSegment && !began && actor.motion.isWalking }
                    if began { break }
                }
                let contact = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
                print("OBSERVATION: \(friend.rawValue) \(spot.rawValue) maximum automatic step = \(maxStep)pt")
                continuous = continuous && maxStep <= 2.5
                arrives = arrives && began && hypot(contact.x - point.x, contact.y - point.y) <= ActivitySpotWorld.arrivalRadius + 0.1
                positionsPreserved = positionsPreserved && desktop.itemWorld.ground == ground && desktop.chiikawaWorld.ground == otherGround
                    && (friend == .hachiware ? desktop.activityWorld.positions : desktop.chiikawaStudyWorld.positions) == initialSpots
                offset += 20
            }
        }
        check(continuous, "automatic encounters never jump either character to a nearby prop")
        check(walksLastSegment && arrives, "both characters walk the last 28 points and start each action only after reaching its anchor")
        check(positionsPreserved, "walking all the way to an activity keeps every ground item and activity prop fixed")

        desktop.stopDailyAction(); desktop.stopChiikawaLife()
        state.roaming = false; state.automaticActivities = true; state.chiikawaAutomaticActivities = true
        state.enabledActivitySpots = [.desk]; state.chiikawaStudyEnabled = true; state.chiikawaFoodEnabled = false
        desktop.activityWorld = ActivitySpotWorld(); desktop.chiikawaStudyWorld = ActivitySpotWorld()
        tick(offset)
        for actor in desktop.actors {
            let anchor = actor.friend == .hachiware ? desktop.activityWorld.positions[.desk]! : desktop.chiikawaStudyWorld.positions[.desk]!
            actor.panel.setFrameOrigin(ItemWorld.destination(for: anchor).offsetBy(dx: -28, dy: 0)); actor.motion.retarget()
        }
        let pausedOrigins = desktop.actors.map { $0.panel.frame.origin }
        tick(offset + 0.1)
        check(!state.roaming && desktop.actors.map { $0.panel.frame.origin } == pausedOrigins
              && desktop.activityWorld.requested == nil && desktop.chiikawaStudyWorld.requested == nil,
              "automatic proximity never turns paused walking back on or moves a paused character")
        state.enabledActivitySpots = []; state.chiikawaStudyEnabled = false; state.chiikawaFoodEnabled = false
        state.automaticActivities = false; state.chiikawaAutomaticActivities = false; state.roaming = false
        tick(offset)
        for (index, actor) in desktop.actors.enumerated() {
            actor.panel.setFrameOrigin(RoamingMotion.target(in: bounds, size: actor.panel.frame.size,
                xFraction: 0.48 + CGFloat(index) * 0.15, yFraction: 0.66))
            actor.motion.retarget()
        }
        desktop.playDailyAction(.study, now: now.addingTimeInterval(offset))
        desktop.playChiikawaLife(.pajamas, now: now.addingTimeInterval(offset))
        let origins = desktop.actors.map { $0.panel.frame.origin }
        for _ in 0..<5 { NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil) }
        check(desktop.actors.map { $0.panel.frame.origin } == origins,
              "repeated display notifications keep both on-screen characters at their current positions")
        check(desktop.hachiwareActor?.dailyPerformance.selected == .study && desktop.chiikawaLifeRoutine.selected == .pajamas,
              "display notifications do not cancel daily actions or wake resting friends")

        let area = NSRect(x: 0, y: 0, width: 1400, height: 900), size = NSSize(width: 132, height: 150)
        var motion = RoamingMotion(destination: NSPoint(x: 1100, y: 500))
        _ = motion.advance(from: NSPoint(x: 100, y: 200), dt: 1.0 / 60, bounds: area, size: size)
        let movedByWindowServer = NSPoint(x: 600, y: 400)
        let resumed = motion.advance(from: movedByWindowServer, dt: 1.0 / 60, bounds: area, size: size)
        check(hypot(resumed.x - movedByWindowServer.x, resumed.y - movedByWindowServer.y) < 1,
              "a window repositioned externally resumes from its displayed location instead of jumping back to cached coordinates")
        let left = NSRect(x: -1280, y: 0, width: 1280, height: 900), right = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let negative = NSPoint(x: -1100, y: 200)
        check(DesktopGeometry.repairedOrigin(negative, size: size, visibleFrames: [left, right]) == negative
              && DesktopGeometry.repairedOrigin(negative, size: size, visibleFrames: []) == negative,
              "display repair preserves valid negative-screen coordinates and waits safely if no screen is available")
        check(DesktopGeometry.repairedOrigin(negative, size: size, visibleFrames: [right]) == NSPoint(x: 0, y: 200)
              && DesktopGeometry.repairedOrigin(NSPoint(x: -40, y: 200), size: size, visibleFrames: [left, right]) == NSPoint(x: 0, y: 200),
              "only off-screen windows move, to the nearest valid point rather than a fixed starting position")
        var preciseArrivals = true
        for scale: CGFloat in [1, 2] { for rule in [FloatingPointRoundingRule.down, .toNearestOrAwayFromZero] { for index in 0..<24 {
            let goal = NSPoint(x: 480.23, y: 320.79), angle = CGFloat(index) / 24 * 2 * .pi
            var rendered = NSPoint(x: ((goal.x + cos(angle) * 28) * scale).rounded(rule) / scale,
                                   y: ((goal.y + sin(angle) * 28) * scale).rounded(rule) / scale)
            var approach = RoamingMotion(destination: goal), reached = false
            for _ in 0..<900 {
                approach.destination = goal
                let next = approach.advance(from: rendered, dt: 1.0 / 60, bounds: area, size: size, stoppingDistance: 0.5)
                rendered = NSPoint(x: (next.x * scale).rounded(rule) / scale, y: (next.y * scale).rounded(rule) / scale)
                if hypot(rendered.x - goal.x, rendered.y - goal.y) <= ActivitySpotWorld.arrivalRadius { reached = true; break }
            }
            preciseArrivals = preciseArrivals && reached
        } } }
        check(preciseArrivals, "the final walking segment reaches the activity radius from all angles with standard and Retina window quantization")
    }
}

private extension NSPoint {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> NSPoint { NSPoint(x: x + dx, y: y + dy) }
}
