import AppKit

extension SelfTest {
    static func runItemDropChecks(defaults: UserDefaults, check: (Bool, String) -> Void) {
        let state = AppState(defaults: defaults)
        state.enabledItems = Set(CompanionItem.allCases)
        state.enabledActivitySpots = Set(ActivitySpot.allCases)
        state.automaticItems = false; state.automaticActivities = false
        state.roaming = false; state.expressive = true; state.homeEnabled = false
        state.showFriends = true; state.characterVoice = false; state.voice = false
        let desktop = DesktopController(state: state, startTimer: false)
        let actor = desktop.actors[0], now = Date(), away = NSPoint(x: -10000, y: -10000)
        desktop.tick(now: now, pointer: away)
        let body = NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY + 15)
        let far = NSPoint(x: actor.panel.frame.maxX + 200, y: actor.panel.frame.midY)
        let lifeProps = desktop.activityWorld.positions, characterOrigin = actor.panel.frame.origin

        desktop.desktopItems[.camera]!.view.onMove?(far)
        let farGround = desktop.itemWorld.ground
        desktop.desktopItems[.camera]!.view.onMoveEnd?(far)
        check(desktop.itemWorld.equipped == nil && desktop.itemWorld.ground == farGround,
              "dropping a dragged item away from the character leaves it on the desktop")

        desktop.desktopItems[.camera]!.view.onMove?(body)
        check(ItemWorld.canReach(body,from:characterOrigin) && desktop.itemWorld.equipped == nil,
              "the body-level handoff is reachable without equipping an item that is still being moved")
        desktop.desktopItems[.camera]!.view.isDragging = true
        check(!desktop.receiveDroppedItem(.camera, at: body),
              "holding a dragged item over the character does not equip it before release")
        desktop.desktopItems[.camera]!.view.isDragging = false
        desktop.desktopItems[.camera]!.view.onMoveEnd?(body)
        check(desktop.itemWorld.equipped == .camera && actor.view.equipped == .camera
              && desktop.itemWorld.ground[.camera] == nil && !desktop.desktopItems[.camera]!.panel.isVisible,
              "the actual item drag-release callback immediately equips and displays a body-level handoff")
        check(!state.roaming && !state.automaticItems && actor.panel.frame.origin == characterOrigin,
              "direct handoff works with automatic pickup and walking off without moving the character")

        desktop.playDailyAction(.study)
        let untouchedWeapon = desktop.itemWorld.ground[.sasumata]
        desktop.desktopItems[.guitar]!.view.onMove?(body)
        desktop.desktopItems[.guitar]!.view.onMoveEnd?(body)
        check(desktop.itemWorld.equipped == .guitar && actor.view.equipped == .guitar
              && desktop.itemWorld.ground[.camera] != nil && desktop.itemWorld.ground[.guitar] == nil
              && desktop.itemWorld.ground.count == 2 && !state.dailyActionRunning,
              "handing over a replacement stops studying and drops the old item without duplication")
        check(desktop.itemWorld.ground[.sasumata] == untouchedWeapon && desktop.activityWorld.positions == lifeProps,
              "a replacement handoff never relocates unrelated carried-item or life-prop coordinates")
        let inventory = desktop.itemWorld.ground
        check(!desktop.receiveDroppedItem(.guitar, at: body) && desktop.itemWorld.ground == inventory,
              "an already carried item cannot be handed over or duplicated a second time")

        desktop.seekActivitySpot(.desk)
        state.roaming = false
        actor.say("Fixture notification", now: now, duration: 20)
        let bubble = actor.bubble, bubbleUntil = actor.bubbleUntil
        desktop.desktopItems[.sasumata]!.view.onMove?(body)
        desktop.desktopItems[.sasumata]!.view.onMoveEnd?(body)
        check(desktop.itemWorld.equipped == .sasumata && desktop.activityWorld.requested == nil
              && !state.activityJourneyRunning && actor.view.action == .surprised
              && actor.bubble === bubble && actor.bubbleUntil == bubbleUntil,
              "an intentional handoff cancels a pending prop visit while preserving a notification and its reaction")

        state.showFriends = false
        let hiddenInventory = desktop.itemWorld.ground
        check(!desktop.receiveDroppedItem(.camera, at: body) && desktop.itemWorld.ground == hiddenInventory,
              "an invisible character does not accept an item dropped at its old coordinates")
        state.showFriends = true; state.enabledItems.remove(.camera)
        check(!desktop.receiveDroppedItem(.camera, at: body), "a disabled item cannot be handed over before the next display update")
        actor.dismissBubble(); actor.panel.orderOut(nil); desktop.home.panel.orderOut(nil)
        desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
        desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
    }
}
