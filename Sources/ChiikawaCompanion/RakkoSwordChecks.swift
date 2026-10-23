import AppKit

extension SelfTest {
    static func runRakkoSwordChecks(check: (Bool,String)->Void) {
        for enabled in [true,false] {
            let suite="RakkoSwordMigration-\(UUID().uuidString)", defaults=UserDefaults(suiteName:suite)!
            defer { defaults.removePersistentDomain(forName:suite) }
            var old=RosterOptions(); old.items=enabled ? [.keepsake]:[]
            old.automaticItems=false; old.automaticRest=false; old.voice=false
            defaults.set(try! JSONEncoder().encode([Friend.rakko:old]),forKey:"rosterOptionsV38")
            defaults.set(Friend.developmentRoster.map(\.rawValue),forKey:"introducedCompanionsV38")
            defaults.set(["hachiware"],forKey:"visibleFriends")
            let state=AppState(defaults:defaults), restored=state.options(for:.rakko)
            check(restored.items == (enabled ? [.weapon,.keepsake]:[]) && !restored.automaticItems
                  && !restored.automaticRest && !restored.voice && !state.visibleFriends.contains(.rakko),
                  "Rakko sword migration extends only an enabled inventory and preserves hidden/rest/audio preferences (enabled=\(enabled))")
            state.updateOptions(.rakko) { $0.items.remove(.weapon) }
            check(!AppState(defaults:defaults).options(for:.rakko).items.contains(.weapon),
                  "Rakko sword migration runs once and never restores a subsequently disabled weapon")
        }
        let art=RosterSprites.shared(.rakko)
        check(art.actions[.attack]?.count == 12 && Set(art.actions[.attack]!.compactMap(\.tiffRepresentation)).count == 12,
              "Rakko has twelve distinct chronological sword swings rather than a reused pole animation")
        check(RosterItemKind.weapon.name(for:.rakko) == "검과 칼집"
              && RosterItemKind.weapon.name(for:.usagi) == "노란 토벌봉",
              "Rakko's silver sword is identified separately from Usagi's yellow staff")
        let suite="RakkoSwordDrop-\(UUID().uuidString)", defaults=UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let state=AppState(defaults:defaults)
        state.visibleFriends=[.rakko,.hachiware]; state.characterVoice=false
        state.automaticItems=false;state.automaticActivities=false;state.automaticRest=false
        state.updateOptions(.rakko) { $0.automaticItems=false;$0.automaticRest=false;$0.voice=false }
        let desktop=DesktopController(state:state,startTimer:false)
        defer {
            desktop.actors.forEach { $0.dismissBubble();$0.panel.orderOut(nil);$0.attackOverlay.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil)
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
            desktop.expansions.values.forEach { $0.objects.values.forEach { $0.panel.orderOut(nil) } }
        }
        let rakko=desktop.expansions[.rakko]!, actor=rakko.actor, prop=RosterProp(owner:.rakko,kind:.weapon)
        let bounds=rakko.usableFrame
        actor.panel.setFrameOrigin(RoamingMotion.target(in:bounds,size:actor.panel.frame.size,xFraction:0.2,yFraction:0.7))
        desktop.hachiwareActor!.panel.setFrameOrigin(RoamingMotion.target(in:bounds,size:Friend.hachiware.actorSize,xFraction:0.8,yFraction:0.7))
        actor.panel.orderFrontRegardless()
        let item=rakko.objects[prop]!
        item.view.onSeek?()
        check(rakko.world.requested == prop && state.isWalking(.rakko),"clicking Rakko's ground scabbard requests the sword and starts an owned walking route")
        let ground=rakko.world.ground
        item.view.onMoveEnd?(desktop.hachiwareActor!.panel.frame.center)
        check(rakko.world.equipped == nil && rakko.world.ground == ground,
              "dropping Rakko's sword on Hachiware cannot give away its owner or remove the ground item")
        item.view.onMoveEnd?(actor.panel.frame.center)
        check(rakko.world.equipped == prop && rakko.action == .pickup && rakko.world.ground[prop] == nil,
              "the real sword drag callback equips Rakko immediately even with automatic pickup disabled")
        let parfait=RosterProp(owner:.rakko,kind:.keepsake), parfaitPosition=rakko.world.ground[parfait]
        actor.view.onDragStart?();actor.panel.setFrameOrigin(NSPoint(x:actor.panel.frame.minX+42,y:actor.panel.frame.minY+30));actor.view.onDragEnd?()
        check(rakko.world.equipped == prop && rakko.world.ground[parfait] == parfaitPosition,
              "dragging an armed Rakko moves only Rakko and preserves the independent parfait coordinates")
        state.setItemsEnabled(false,for:.rakko);rakko.configure()
        check(rakko.world.equipped == nil && rakko.world.ground.isEmpty,
              "Rakko's existing master item switch removes both the carried sword and ground parfait")
        state.setItemsEnabled(true,for:.rakko);rakko.configure()
        check(rakko.world.ground.count == 2 && Set(rakko.world.ground.keys.map(\.kind)) == [.weapon,.keepsake],
              "reenabling the same master switch creates exactly one sword and one parfait")
    }
}

private extension NSRect { var center: NSPoint { NSPoint(x:midX,y:midY) } }
