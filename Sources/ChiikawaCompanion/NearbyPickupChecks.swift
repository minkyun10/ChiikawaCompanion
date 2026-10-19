import AppKit

extension SelfTest {
    static func runNearbyPickupChecks(defaults: UserDefaults, check: (Bool, String) -> Void) {
        let bounds = NSRect(x:-500,y:-300,width:1500,height:1000), now = Date()
        let origin = NSPoint(x:50,y:80), contact = ItemWorld.contactPoint(origin:origin)
        let upperContact = NSPoint(x:contact.x+64,y:contact.y+70)
        check(hypot(upperContact.x-contact.x,upperContact.y-contact.y)>30
              && ItemWorld.canReach(upperContact,from:origin),
              "a prop touching the upper side of the drawn body is reachable beyond the old 30-point foot circle")
        check(!ItemWorld.canReach(NSPoint(x:contact.x+180,y:contact.y+180),from:origin),
              "the visual pickup area does not grab distant props")
        var world = ItemWorld()
        world.configure(enabled:Set(CompanionItem.allCases),bounds:bounds)
        world.move(.camera,to:contact,bounds:bounds)
        _ = world.pickUp(.camera,from:origin,bounds:bounds,now:now)
        world.move(.guitar,to:upperContact,bounds:bounds)
        check(world.target(from:origin,automatic:true,now:now.addingTimeInterval(4)) == nil
              && world.nearbyTarget(from:origin,automatic:true,now:now.addingTimeInterval(4)) == .guitar,
              "a nearby encounter is independent of the 24-second automatic seek cooldown")
        check(world.nearbyTarget(from:origin,automatic:true,now:now.addingTimeInterval(2)) == nil,
              "the short three-second encounter cooldown prevents rapid automatic item flicker")
        check(world.nearbyTarget(from:origin,automatic:false,now:now.addingTimeInterval(4)) == nil
              && world.nearbyTarget(from:origin,automatic:true,now:now.addingTimeInterval(4),excluding:[.guitar]) == nil,
              "passing pickup respects automatic-off and never grabs a prop during its drag")
        let untouchedWeapon = world.ground[.sasumata]
        check(world.pickUp(.guitar,from:origin,bounds:bounds,now:now.addingTimeInterval(4))
              && world.equipped == .guitar && world.ground[.camera] != nil && world.ground[.guitar] == nil
              && world.ground[.sasumata] == untouchedWeapon,
              "visual contact swaps the held item while keeping unrelated props fixed")
        let camera = world.ground[.camera]!
        check(world.nearbyTarget(from:ItemWorld.destination(for:camera),automatic:true,now:now.addingTimeInterval(8)) != .camera,
              "a recently dropped old item keeps its own twelve-second no-repickup delay")
        world.requested = .sasumata
        check(world.nearbyTarget(from:origin,automatic:true,now:now.addingTimeInterval(20)) == nil,
              "incidental contact does not replace an explicitly requested item journey")

        let state = AppState(defaults:defaults)
        state.enabledItems = Set(CompanionItem.allCases); state.automaticItems = true
        state.automaticActivities = false; state.homeEnabled = false
        state.characterVoice = false; state.voice = false; state.expressive = false
        state.showFriends = true; state.roaming = true
        let desktop = DesktopController(state:state,startTimer:false), actor = desktop.actors[0]
        let area = NSScreen.main!.visibleFrame, away = NSPoint(x:-10000,y:-10000)
        let start = RoamingMotion.target(in:area,size:actor.panel.frame.size,xFraction:0.5,yFraction:0.5)
        actor.panel.setFrameOrigin(start)
        let anchor = ItemWorld.contactPoint(origin:start)
        desktop.itemWorld.move(.camera,to:anchor,bounds:area)
        _ = desktop.itemWorld.equip(.camera,at:start,bounds:area,now:now)
        let passing = NSPoint(x:anchor.x+64,y:anchor.y+70)
        desktop.itemWorld.move(.guitar,to:passing,bounds:area)
        let fixedWeapon = desktop.itemWorld.ground[.sasumata], life = desktop.activityWorld.positions
        desktop.itemTarget = .sasumata
        actor.motion.destination = RoamingMotion.target(in:area,size:actor.panel.frame.size,xFraction:0.9,yFraction:0.8)
        desktop.tick(now:now.addingTimeInterval(4),pointer:away,pointerCanReachCharacter:true)
        check(desktop.itemWorld.equipped == .guitar && actor.view.equipped == .guitar
              && desktop.itemWorld.ground[.guitar] == nil,
              "the live update grabs a body-touching item during the seek cooldown even with a different old route target")
        check(desktop.itemWorld.ground[.sasumata] == fixedWeapon && desktop.activityWorld.positions == life,
              "a passing pickup keeps other item and life-prop coordinates unchanged")

        // Cross from just outside to just inside the rounded body in one real movement tick.
        desktop.itemWorld.configure(enabled:[.camera],bounds:area)
        state.enabledItems = [.camera]
        actor.panel.setFrameOrigin(start); actor.motion.retarget()
        let boundary = NSPoint(x:anchor.x+82.2,y:anchor.y+43)
        desktop.itemWorld.move(.camera,to:boundary,bounds:area)
        actor.motion.destination = NSPoint(x:start.x+200,y:start.y)
        check(!ItemWorld.canReach(boundary,from:start), "the encounter boundary fixture begins outside contact")
        desktop.tick(now:now.addingTimeInterval(20),pointer:away,pointerCanReachCharacter:true)
        check(desktop.itemWorld.equipped == .camera && actor.view.equipped == .camera,
              "the post-movement check equips on the same tick that the body first touches a prop")
        actor.dismissBubble(); actor.panel.orderOut(nil); desktop.home.panel.orderOut(nil)
        desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
        desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
    }
}
