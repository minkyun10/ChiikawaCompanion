import AppKit

extension SelfTest {
    static func runActivitySpotChecks(defaults: UserDefaults, check: (Bool, String) -> Void) {
        let bounds = NSRect(x: 0,y: 0,width: 1200,height: 800), now = Date()
        var world = ActivitySpotWorld()
        world.configure(enabled: Set(ActivitySpot.allCases), bounds: bounds)
        let initial = world.positions, desk = initial[.desk]!
        check(world.positions.count == 3 && ActivitySpot.desk.action == .study
              && ActivitySpot.furball.action == .vomit && ActivitySpot.rice.action == .eat,
              "the independent desk, furball and rice props map to the three approved daily actions")
        check(world.encounter(contact: desk, automatic: true, now: now) == .desk
              && world.encounter(contact: desk, automatic: false, now: now) == nil,
              "proximity actions obey the automatic-reaction switch")
        check(world.encounter(contact: desk, automatic: true, now: now, excluding: [.desk]) == nil,
              "a dragged prop cannot trigger its action before release")
        world.consume(.desk, now: now)
        world.observe(contact: desk)
        check(world.encounter(contact: desk, automatic: true, now: now.addingTimeInterval(300)) == nil,
              "standing at the same desk never repeatedly restarts studying after a timeout")
        world.observe(contact: NSPoint(x: desk.x+ActivitySpotWorld.exitRadius+2,y: desk.y))
        check(world.encounter(contact: desk, automatic: true, now: now.addingTimeInterval(1)) == nil
              && world.encounter(contact: desk, automatic: true, now: now.addingTimeInterval(31)) == .desk,
              "a repeat encounter needs both leaving the prop and finishing its cooldown")
        world.consume(.desk, now: now); world.requested = .desk
        check(world.encounter(contact: desk, automatic: false, now: now) == .desk,
              "explicitly clicking a prop can request another visit without waiting for automatic rearming")
        world.move(.rice, to: NSPoint(x: 700,y: 200), bounds: bounds)
        check(world.positions[.desk] == initial[.desk] && world.positions[.furball] == initial[.furball]
              && world.positions[.rice] != initial[.rice], "dragging one life prop leaves the other world coordinates unchanged")
        world.configure(enabled: [.furball,.rice], bounds: bounds)
        check(world.positions[.desk] == nil && world.requested == nil && !world.latched.contains(.desk),
              "hiding a prop removes its trigger and clears a pending visit")

        let state = AppState(defaults: defaults)
        state.characterVoice = false;
        state.automaticItems = false; state.automaticActivities = true; state.expressive = false; state.roaming = false
        state.enabledActivitySpots = Set(ActivitySpot.allCases)
        let desktop = DesktopController(state: state, startTimer: false), actor = desktop.actors[0]
        let spots = desktop.activityWorld.positions, items = desktop.itemWorld.ground
        let away = NSPoint(x: -10000,y: -10000)
        var time = Date().addingTimeInterval(1)
        var allActions = true, allReleased = true, noRepeats = true
        for spot in ActivitySpot.allCases {
            actor.panel.setFrameOrigin(ItemWorld.destination(for: spots[spot]!))
            desktop.tick(now: time, pointer: away)
            let actualContact = ItemWorld.contactPoint(origin: actor.panel.frame.origin), anchor = spots[spot]!
            check(actor.view.action == spot.action && desktop.activeActivitySpot == spot,
                  "\(spot.rawValue) direct-anchor action starts (window/anchor distance \(hypot(actualContact.x-anchor.x,actualContact.y-anchor.y))pt, action \(String(describing: actor.view.action)), active \(String(describing: desktop.activeActivitySpot)))")
            allActions = allActions && actor.view.action == spot.action && desktop.activeActivitySpot == spot
                && state.dailyActionRunning && desktop.activityWorld.positions == spots && desktop.itemWorld.ground == items
            if spot != .furball { allActions = allActions && !desktop.desktopActivitySpots[spot]!.panel.isVisible }
            check(!desktop.triggerNearbyActivity(actor, now: time.addingTimeInterval(0.1)),
                  "a running \(spot.name) action cannot be replaced by another automatic proximity check")
            time = time.addingTimeInterval(spot.action.duration+0.2)
            desktop.tick(now: time, pointer: away)
            allReleased = allReleased && !state.dailyActionRunning && desktop.activeActivitySpot == nil
                && desktop.desktopActivitySpots[spot]!.panel.isVisible
            time = time.addingTimeInterval(100)
            desktop.tick(now: time, pointer: away)
            noRepeats = noRepeats && !state.dailyActionRunning
            time = time.addingTimeInterval(1)
        }
        check(allActions, "the live update starts study, spit-up and eating at their own fixed prop anchors without moving any prop")
        check(allReleased && noRepeats, "finished actions reveal the same props and stay idle until the character leaves")

        desktop.stopDailyAction()
        let far = ItemWorld.destination(for: spots[.rice]!)
        actor.panel.setFrameOrigin(far)
        desktop.desktopActivitySpots[.desk]!.view.onSeek?()
        let journeyStart = actor.panel.frame.origin
        desktop.tick(now: time, pointer: away)
        check(state.activityJourneyRunning && desktop.activityWorld.requested == .desk
              && actor.panel.frame.origin != journeyStart && actor.view.walking && !state.dailyActionRunning,
              "clicking a life prop walks toward it before starting its action")
        actor.panel.setFrameOrigin(ItemWorld.destination(for: spots[.desk]!))
        time = time.addingTimeInterval(0.2); desktop.tick(now: time, pointer: away)
        check(actor.view.action == .study && desktop.activityWorld.requested == nil && !state.activityJourneyRunning,
              "an explicit visit triggers the selected desk only on arrival")
        actor.view.onDragStart?()
        actor.panel.setFrameOrigin(ItemWorld.destination(for: spots[.furball]!))
        // This explicit request also makes the drop check independent of prior fixture cooldowns.
        desktop.activityWorld.requested = .furball
        actor.view.onDragEnd?()
        check(actor.view.action == .vomit && desktop.activeActivitySpot == .furball,
              "dropping the character beside a life prop triggers the matching action immediately")
        desktop.stopDailyAction(); state.automaticActivities = false
        actor.panel.setFrameOrigin(ItemWorld.destination(for: spots[.rice]!))
        time = time.addingTimeInterval(200); desktop.tick(now: time, pointer: away)
        check(!state.dailyActionRunning, "turning off automatic reactions keeps nearby props visible without starting actions")
        state.onSeekActivitySpot?(.rice)
        for _ in 0..<360 {
            time = time.addingTimeInterval(DesktopActivity.updateInterval)
            desktop.lastTick = time.addingTimeInterval(-DesktopActivity.updateInterval)
            desktop.tick(now: time, pointer: away)
            if actor.view.action == .eat { break }
        }
        check(actor.view.action == .eat, "a requested rice visit still works while automatic proximity is off")
        desktop.resetPositions()
        check(desktop.activityWorld.positions == spots && desktop.itemWorld.ground == items,
              "calling or moving the character never scatters life props or carried-item world positions")
        state.automaticActivities = true; state.enabledActivitySpots = [.desk,.rice]
        let reopened = AppState(defaults: defaults)
        check(reopened.automaticActivities && reopened.enabledActivitySpots == [.desk,.rice],
              "life-prop visibility and proximity preferences persist independently")
        actor.dismissBubble(); actor.panel.orderOut(nil); desktop.home.panel.orderOut(nil)
        desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
        desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
    }

    static func renderActivitySpots(to directory: URL) {
        png(width: 900, height: 640, to: directory.appendingPathComponent("hachiware-proximity-actions-v17.png")) {
            NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0,y: 0,width: 900,height: 640).fill()
            for (index, spot) in ActivitySpot.allCases.enumerated() {
                let x = index*300
                ActivitySpotArtwork.draw(spot, in: NSRect(x: x+98,y: 436,width: 104,height: 100))
                ("\(spot.name) → \(spot.action.title)" as NSString).draw(at: NSPoint(x: x+71,y: 395),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 16,weight: .semibold),.foregroundColor: FriendArtwork.ink])
                ("↓" as NSString).draw(at: NSPoint(x: x+141,y: 349), withAttributes:
                    [.font: NSFont.systemFont(ofSize: 26),.foregroundColor: FriendArtwork.ink])
                FriendArtwork.draw(.hachiware, in: NSRect(x: x+22,y: 65,width: 256,height: 256), action: spot.action,
                    actionTime: spot.action.cycleDuration*0.5+0.001)
            }
        }
        for spot in ActivitySpot.allCases {
            png(width: 104,height: 100,to: directory.appendingPathComponent("life-prop-\(spot.rawValue)-v17.png")) {
                ActivitySpotArtwork.draw(spot, in: NSRect(x: 0,y: 0,width: 104,height: 100))
            }
        }
    }
}
