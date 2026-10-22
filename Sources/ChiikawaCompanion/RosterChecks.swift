import AppKit
import AVFoundation

extension SelfTest {
    static func runRosterChecks(check: (Bool, String) -> Void) {
        _ = NSApplication.shared
        runUsagiIdentityChecks(check: check)
        runNewFriendChecks(check: check)
        let migrationSuite = "ExclusiveItemsMigration-\(UUID().uuidString)"
        let migrationDefaults = UserDefaults(suiteName: migrationSuite)!
        defer { migrationDefaults.removePersistentDomain(forName: migrationSuite) }
        let legacyOptions: [Any] = Friend.expansionOrder.flatMap { friend -> [Any] in
            [friend.rawValue, ["items": ["guitar", "camera", "weapon"], "spots": ["desk", "furball", "rice"],
                "automaticItems": false, "automaticActivities": false, "automaticRest": false, "voice": false] as [String: Any]]
        }
        migrationDefaults.set(try! JSONSerialization.data(withJSONObject: legacyOptions), forKey: "rosterOptionsV38")
        let migrated = AppState(defaults: migrationDefaults)
        for friend in Friend.expansionOrder {
            let options = migrated.options(for: friend)
            let expected: Set<RosterItemKind> = friend == .usagi ? [.weapon] : []
            check(options.items == expected && !options.automaticItems && !options.automaticRest && !options.voice,
                  "\(friend.name): old item and activity settings migrate without resetting retained preferences")
            migrated.updateOptions(friend) { $0.items.insert(.weapon) }
            check(migrated.options(for: friend).items == expected,
                  "\(friend.name): settings enforce the weapon owner and keep disabled keepsakes off")
        }
        let persisted = String(data: migrationDefaults.data(forKey: "rosterOptionsV38")!, encoding: .utf8)!
        check(["guitar", "camera", "spots", "automaticActivities", "desk", "furball", "rice"].allSatisfy { !persisted.contains($0) }
              && AppState(defaults: migrationDefaults).rosterOptions == migrated.rosterOptions,
              "removed guitar, desk, rice and automatic activity settings stay absent after reopening")
        check(["guitar", "camera"].allSatisfy { RosterItemKind(rawValue: $0) == nil }
              && ["guitar", "camera", "vomit", "study", "eat"].allSatisfy { RosterAction(rawValue: $0) == nil },
              "expansion commands cannot represent cameras, guitars or retired daily actions")
        check(Set(Friend.developmentRoster.filter(\.canUseWeapon)) == [.hachiware, .chiikawa, .usagi]
              && RosterProp.allCases.filter { $0.kind == .weapon }.map(\.owner) == [.usagi],
              "only Hachiware, Chiikawa and Usagi have weapons in their respective catalogs")
        let suite = "RosterChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["chiikawa"], forKey: "visibleFriends")
        defaults.set(["hachiware"], forKey: "walkingFriends")
        let state = AppState(defaults: defaults)
        let expansion = Friend.developmentRoster.filter(\.isExpansion)
        check(state.visibleFriends == Set([.chiikawa] + expansion) && state.walkingFriends == Set([.hachiware] + expansion),
              "new companions migrate once without unhiding old friends or resetting old walking choices")
        state.visibleFriends = [.hachiware, .chiikawa]; state.walkingFriends = [.hachiware]
        let reopened = AppState(defaults: defaults)
        check(reopened.visibleFriends == [.hachiware,.chiikawa] && reopened.walkingFriends == [.hachiware],
              "hiding a newly introduced companion survives subsequent launches")
        state.visibleFriends = Set(Friend.developmentRoster); state.walkingFriends = Set(Friend.developmentRoster)
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.automaticActivities = false; state.chiikawaAutomaticActivities = false
        state.automaticRest = false; state.chiikawaAutomaticRest = false
        state.characterVoice = false; state.chiikawaVoice = false; state.roaming = true; state.expressive = true
        for friend in expansion { state.updateOptions(friend) { $0.automaticItems = false; $0.automaticRest = false } }
        var voiceStarts = 0
        let desktop = DesktopController(state: state, startTimer: false,
            expansionVoice: { _ in RecordedVoicePlayer(startPlayback: { _ in voiceStarts += 1; return true }) })
        let now = Date(), away = NSPoint(x:-10000,y:-10000)
        var clock: Double = 0
        func tick(_ delta: Double = 1.0/60, mouse: NSPoint? = nil, reachable: Bool = false) {
            clock += delta; let date=now.addingTimeInterval(clock)
            desktop.lastTick=date.addingTimeInterval(-min(delta,1.0/60))
            desktop.tick(now:date,pointer:mouse ?? away,pointerCanReachCharacter:reachable)
        }
        func date() -> Date { now.addingTimeInterval(clock) }
        tick()
        check(desktop.desktopItems[.camera] != nil && desktop.itemWorld.ground[.camera] != nil
              && !ChiikawaItem.allCases.map(\.rawValue).contains("camera"),
              "the only camera ground object belongs to Hachiware")
        check(desktop.desktopItems[.guitar] != nil && desktop.itemWorld.ground[.guitar] != nil
              && desktop.desktopActivitySpots[.furball] != nil && desktop.activityWorld.positions[.furball] != nil,
              "Hachiware keeps the guitar and furball ground objects and interactions")
        check(!ChiikawaItem.allCases.map(\.rawValue).contains("guitar")
              && !ChiikawaLifeAction.allCases.map(\.rawValue).contains("vomit")
              && desktop.chiikawaStudyWorld.positions[.furball] == nil,
              "Chiikawa has neither Hachiware-exclusive item nor a vomiting action")
        check(Set([ActivitySpot.desk, .rice]).isSubset(of: desktop.activityWorld.enabled)
              && desktop.chiikawaStudyWorld.enabled == [.desk, .rice],
              "Hachiware and Chiikawa retain their independent desk and rice worlds")
        guard let bounds=NSScreen.main?.visibleFrame else {check(false,"a desktop exists for roster acceptance");return}
        let fixedHome=desktop.home.panel.frame, homeID=desktop.home.panel.windowNumber
        for friend in expansion {
            let name=friend.name, companion=desktop.expansions[friend]!, actor=companion.actor, art=RosterSprites.shared(friend)
            let prefix="\(name): "
            if Bundle.main.bundleURL.pathExtension == "app" {
                check(art.usesBundledAtlases,prefix+"packaged app loads prebuilt native atlases without runtime generation")
                let root = Bundle.main.resourceURL!.appendingPathComponent("Roster/\(friend.rawValue)")
                let retired = ["guitar-12.png", "vomit-12.png", "study-12.png", "eat-12.png", "camera-12.png"]
                    + (friend.canUseWeapon ? [] : ["attack-12.png"])
                check(retired.allSatisfy {
                    !FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path)
                }, prefix+"packaging excludes all retired item and activity animation atlases")
                check(!FileManager.default.fileExists(atPath: Bundle.main.resourceURL!
                    .appendingPathComponent("\(friend.rawValue)-expression-study-v38.png").path),
                      prefix+"packaging excludes the retired study expression resource")
            }
            let kinds = RosterItemKind.available(for: friend)
            check(Set(companion.objects.keys.map(\.kind)) == Set(kinds)
                  && Set(companion.world.ground.keys.map(\.kind)) == Set(kinds),
                  prefix+"ground windows and inventory contain exactly this character's allowed items")
            let otherActivities = Array(desktop.activityWorld.positions.values) + Array(desktop.chiikawaStudyWorld.positions.values)
            var ignoresOtherActivities = true
            for point in otherActivities {
                actor.panel.setFrameOrigin(ItemWorld.destination(for: point)); companion.stopAction(); tick()
                ignoresOtherActivities = ignoresOtherActivities && companion.action == nil
                    && actor.view.rosterVisual?.action == nil && actor.motion.isWalking
            }
            check(ignoresOtherActivities, prefix+"walking past either original friend's activity props does not trigger studying or eating")
            check(["guitar", "camera"].allSatisfy { RosterProp(rawValue: friend.rawValue + ":" + $0) == nil }
                  && (RosterProp(rawValue: friend.rawValue + ":weapon") != nil) == friend.canUseWeapon,
                  prefix+"stale camera, guitar and disallowed weapon drag payloads are rejected")
            check(art.isReady && art.walks.count==8 && art.actions.count==RosterAction.available(for: friend).count,prefix+"eight walking directions and every allowed action load")
            for direction in ChiikawaDirection.allCases {
                let frames=art.walks[direction] ?? []
                check(frames.count==24 && Set(frames.compactMap(\.tiffRepresentation)).count==24,
                      prefix+"\(direction.rawValue) contains 24 distinct chronological drawings")
            }
            var clear=true, inside=true
            for frame in art.walks.values.flatMap({$0}) {
                let rep=NSBitmapImageRep(data:frame.tiffRepresentation!)!
                for (x,y) in [(0,0),(rep.pixelsWide-1,0),(0,rep.pixelsHigh-1),(rep.pixelsWide-1,rep.pixelsHigh-1)] {
                    clear = clear && (rep.colorAt(x:x,y:y)?.alphaComponent ?? 1)<0.02
                }
                inside = inside && rep.pixelsWide==Int(friend.canvasSize.width) && rep.pixelsHigh==Int(friend.canvasSize.height)
            }
            check(clear && inside,prefix+"walking canvases retain transparent margins and the full ear/body viewport")
            func upperSilhouette(_ attack: Int?) -> NSRect {
                let size=friend.actorSize, canvas=friend.canvasSize
                let rep=RosterNativeRig.bitmap(size) {
                    FriendArtwork.draw(friend,in:NSRect(origin:.zero,size:size),walking:attack == nil,facing:-1,walkPhase:0,
                        action:attack == nil ? nil:.attack,actionTime:attack.map{(Double($0)+0.25)*0.1})
                }
                let scale=min(size.width/canvas.width,size.height/canvas.height)
                let cutoff=(size.height-canvas.height*scale)/2+150*scale
                var result=NSRect.null
                for y in 0..<rep.pixelsHigh {for x in 0..<rep.pixelsWide {
                    let yy=size.height-1-CGFloat(y)
                    if yy>=cutoff && (rep.colorAt(x:x,y:y)?.alphaComponent ?? 0)>0.5 {
                        result=result.union(NSRect(x:x,y:Int(yy),width:1,height:1))
                    }
                }}
                return result
            }
            if friend.canUseWeapon {
                let standing=upperSilhouette(nil)
                check(!standing.isNull && (0..<12).allSatisfy { n in
                    let attack=upperSilhouette(n)
                    return !attack.isNull && abs(attack.width-standing.width)<=2 && abs(attack.midX-standing.midX)<=2
                        && abs(attack.maxY-standing.maxY)<=2
                },prefix+"all attack frames preserve the real walking head width, center and ear crown within two desktop pixels")
            } else {
                check(art.actions[.attack] == nil && art.registration == nil,
                      prefix+"unarmed characters have neither attack frames nor weapon viewport registration")
            }
            check(actor.panel.frame.size==friend.actorSize && actor.panel.level==DesktopLayer.character && !actor.panel.canBecomeKey,
                  prefix+"native panel has the correct nonactivating desktop geometry")
            let start=RoamingMotion.target(in:bounds,size:actor.panel.frame.size,xFraction:0.36,yFraction:0.68)
            actor.panel.setFrameOrigin(start); actor.motion.retarget()
            actor.motion.destination=RoamingMotion.target(in:bounds,size:actor.panel.frame.size,xFraction:0.8,yFraction:0.7)
            let ground=companion.world.ground, oldHachi=desktop.itemWorld.ground,oldChii=desktop.chiikawaWorld.ground
            var maxJump:CGFloat=0
            for _ in 0..<240 {let old=actor.panel.frame.origin;tick();let p=actor.panel.frame.origin;maxJump=max(maxJump,hypot(p.x-old.x,p.y-old.y))}
            check(maxJump<2 && hypot(actor.panel.frame.minX-start.x,actor.panel.frame.minY-start.y)>60,
                  prefix+"native walking moves continuously with no resets or teleporting")
            check(companion.world.ground==ground && desktop.itemWorld.ground==oldHachi && desktop.chiikawaWorld.ground==oldChii,
                  prefix+"walking leaves every character's ground items and activity coordinates independent")
            actor.view.onDragStart?(); actor.panel.setFrameOrigin(start); actor.view.onDragEnd?()
            check(companion.world.ground==ground && actor.motion.destination==nil,
                  prefix+"actual drag callbacks reset only the route and preserve prop positions")
            let center=actor.panel.frame.center
            check(!companion.receive(.keepsake,at:desktop.hachiwareActor!.panel.frame.center,now:date()),
                  prefix+"a prop dropped on a different owner is rejected")
            check(companion.receive(.keepsake,at:center,now:date()) && companion.world.equipped?.kind == .keepsake,
                  prefix+"direct drag drop equips immediately with automatic pickup disabled")
            if friend.canUseWeapon {
                check(companion.receive(.weapon,at:center,now:date()) && companion.world.equipped?.kind == .weapon
                      && companion.world.ground[RosterProp(owner:friend,kind:.keepsake)] != nil,
                      prefix+"swapping to the allowed weapon drops exactly the old owned item")
            } else {
                check(!companion.receive(.weapon,at:center,now:date()) && companion.world.equipped?.kind == .keepsake,
                      prefix+"a forbidden weapon handover preserves the currently held keepsake")
            }
            companion.drop(now:date())
            check(companion.world.equipped==nil && companion.world.ground.count==kinds.count,
                  prefix+"manual drop restores one instance of each enabled item")
            companion.seek(.keepsake,now:date()); tick()
            check(companion.world.requested?.kind == .keepsake && actor.motion.isWalking,prefix+"ground item seek follows a walking route")
            companion.world.requested=nil; companion.itemTarget=nil; companion.stopAction()
            actor.panel.setFrameOrigin(start);companion.wake(now:date());companion.stopAction()
            if friend.canUseWeapon {
            check(companion.receive(.weapon,at:actor.panel.frame.center,now:date()),prefix+"weapon handover succeeds")
            companion.stopAction();tick(0.1,mouse:actor.panel.frame.center,reachable:true)
            check(actor.view.action == .attack && actor.view.rosterVisual?.action == .attack && !actor.view.walking,
                  prefix+"weapon hover selects attack exclusively")
            let attackStart=actor.hoverStarted, pausedGait=actor.gait.phase, attackOrigin=actor.panel.frame.origin
            var stable=true
            for _ in 0..<180 {tick(mouse:actor.panel.frame.center,reachable:true);stable = stable && actor.view.action == .attack && actor.hoverStarted==attackStart && actor.panel.frame.origin==attackOrigin && actor.gait.phase==pausedGait}
            check(stable,prefix+"three-second hover retains one attack clock, fixed scale and stationary gait")
            let mask=ArmedPointerArtwork.shared.attack(friend)
            check(mask.rect.contains(NSRect(origin:.zero,size:friend.actorSize)) && mask.rect.width>friend.actorSize.width,
                  prefix+"stable attack mask includes the complete expanded weapon viewport")
            tick(mouse:actor.panel.frame.center,reachable:false)
            check(actor.view.action != .attack && actor.armedHoverContact==nil,prefix+"foreground occlusion releases armed hover")
            tick()
            check(actor.view.action == nil && actor.view.rosterVisual?.action == nil && actor.view.walking,
                  prefix+"leaving hover returns to walking in one display update")
            companion.play(.keepsake,now:date());tick(mouse:actor.panel.frame.center,reachable:true)
            check(companion.action == nil && actor.view.rosterVisual?.action == .attack && actor.view.action == .attack,
                  prefix+"armed hover interrupts a prop action and displays only the attack")
            } else {
                companion.play(.keepsake, now:date())
                let began = companion.actionStarted
                companion.command(.action(.attack))
                check(companion.action == .keepsake && companion.actionStarted == began,
                      prefix+"a forbidden direct attack leaves the current allowed action untouched")
                companion.stopAction(); tick(mouse:actor.panel.frame.center,reachable:true)
                check(actor.view.action != .attack && actor.view.rosterVisual?.action != .attack
                      && !actor.attackOverlay.panel.isVisible,
                      prefix+"ordinary hover never displays an attack or weapon overlay")
                tick()
                check(actor.view.walking, prefix+"leaving ordinary hover resumes walking immediately")
            }
            companion.stopAction();actor.dismissBubble()
            let beforeAudio=voiceStarts
            for _ in 0..<30 {tick(mouse:actor.panel.frame.center,reachable:true)}
            check(voiceStarts==beforeAudio,prefix+"autonomous movement and armed hover never start audio")
            if !friend.isNewSingleItemFriend {
            check(companion.catalog.isValid && companion.catalog.clips.count == 4,
                  prefix+"four authentic credited actor-demo excerpts load from bundled resources")
            check(companion.catalog.clips.allSatisfy { clip in
                guard let url=clip.resourceURL,let audio=try? AVAudioPlayer(contentsOf:url) else {return false}
                return abs(audio.duration-clip.duration)<0.08 && audio.duration>0 && audio.duration<=15
            },prefix+"every real clip decodes with its own matching duration")
            state.updateOptions(friend){$0.voice=false};companion.previewVoice();tick()
            check(companion.voice.player != nil && !state.options(for:friend).voice,
                  prefix+"explicit preview plays while click voice is muted without changing that preference")
            companion.voice.stop();state.updateOptions(friend){$0.voice=true};companion.previewVoice()
            state.updateOptions(friend){$0.voice=false}
            check(companion.voice.player==nil,prefix+"muting a character immediately stops its current voice")
            state.updateOptions(friend){$0.voice=true}
            } else {
                let starts=voiceStarts
                companion.previewVoice();companion.clicked(now:date())
                check(companion.catalog.clips.isEmpty && companion.voice.player == nil && voiceStarts == starts,
                      prefix+"unverified voices remain unavailable and clicks use local captions only")
                check(RosterItemKind.available(for:friend) == [.keepsake] && !friend.canUseWeapon,
                      prefix+"exactly one characteristic item and no weapon are registered")
            }
            var previous:String?, noRepeat=true, captions=true
            for _ in 0..<100 {
                companion.clicked(now:date())
                noRepeat = noRepeat && companion.lastDialogueID != previous;previous=companion.lastDialogueID
                let shown=(actor.bubble?.contentView?.subviews.last as? NSTextField)?.stringValue ?? ""
                captions = captions && (friend.reactionTexts.contains(shown) || companion.catalog.clips.contains {$0.text==shown})
            }
            check(noRepeat && captions,prefix+"clicks choose matching local captions without immediate repeats")
            companion.voice.stop();actor.dismissBubble()
            let oldStyle=state.homeStyle, inventory=companion.world.ground
            companion.goHome(now:date());tick()
            check(companion.home.phase == .returning && actor.motion.isWalking,prefix+"home command begins an actual walk to the common entrance")
            actor.panel.setFrameOrigin(ItemWorld.destination(for:desktop.home.entrance));companion.endedDragging(now:date());tick(1)
            check(companion.home.phase == .sleeping && !actor.panel.isVisible && companion.world.equipped==nil,
                  prefix+"entering the house drops equipment and sleeps using its own routine")
            let began=companion.home.phaseStarted
            state.homeStyle = oldStyle == .hachiware ? .chiikawa : .hachiware;tick()
            check(desktop.home.panel.windowNumber==homeID && desktop.home.panel.frame==fixedHome && companion.home.phaseStarted==began,
                  prefix+"house skin changes retain the single fixed window and sleeping clock")
            companion.wake(now:date(),animated:true);tick(1.1)
            check(actor.panel.isVisible && !companion.home.isInside && companion.wakingAt==nil,
                  prefix+"waking finishes and restores the character outside the shared doorway")
            companion.play(.keepsake,now:date());state.visibleFriends.remove(friend);tick()
            check(!actor.panel.isVisible && companion.action==nil && companion.voice.player==nil && !actor.attackOverlay.panel.isVisible,
                  prefix+"hiding cancels only its own action, audio and overlay")
            state.visibleFriends.insert(friend);tick()
            state.updateOptions(friend){$0.voice=false;$0.automaticRest=false;$0.items.remove(.keepsake)};tick()
            let saved=AppState(defaults:defaults).options(for:friend)
            check(!saved.voice && !saved.automaticRest && !saved.items.contains(.keepsake)
                  && companion.world.ground[RosterProp(owner:friend,kind:.keepsake)]==nil,
                  prefix+"independent item, rest and voice options persist and disabled props disappear")
            check(inventory.keys.allSatisfy {$0.owner==friend},prefix+"every inventory key retains its explicit owner")
        }
        check(desktop.expansions.count==expansion.count && Set(desktop.actors.map(\.friend)).count==Friend.developmentRoster.count,
              "every active companion owns exactly one independent controller and native actor")
        for actor in desktop.actors {
            actor.dismissBubble();desktop.wakeFriend(actor.friend,now:date())
            if let companion=desktop.expansions[actor.friend] {
                companion.wake(now:date());companion.stopAction()
                state.updateOptions(actor.friend){$0.automaticItems=false;$0.automaticRest=false}
            }
            actor.panel.setFrameOrigin(RoamingMotion.target(in:bounds,size:actor.panel.frame.size,xFraction:0.2,yFraction:0.7))
            actor.motion.retarget()
        }
        desktop.stopDailyAction();desktop.stopChiikawaLife()
        state.showFriends=true;state.visibleFriends=Set(Friend.developmentRoster);state.roaming=true
        desktop.activateSharedHome(now:date())
        for actor in desktop.actors {
            actor.panel.setFrameOrigin(ItemWorld.destination(for:desktop.home.entrance))
            switch actor.friend {
            case .hachiware:_ = desktop.enterHomeIfReached(actor,now:date())
            case .chiikawa:desktop.didMoveChiikawa(actor,now:date())
            default:desktop.expansions[actor.friend]?.endedDragging(now:date())
            }
        }
        tick(1.1)
        check(Set(desktop.homeOccupants.map(\.friend))==Set(Friend.developmentRoster)
              && desktop.actors.allSatisfy{!$0.panel.isVisible},
              "all active friends can sleep simultaneously in the one shared house")
        let phases=desktop.homeRoutines.mapValues(\.phaseStarted), ground=desktop.expansions.mapValues{$0.world.ground}
        state.homeStyle = state.homeStyle == .hachiware ? .chiikawa:.hachiware;tick()
        check(desktop.home.panel.windowNumber==homeID && desktop.home.panel.frame==fixedHome
              && desktop.homeRoutines.mapValues(\.phaseStarted)==phases && desktop.expansions.mapValues{$0.world.ground}==ground,
              "changing the shared house design preserves every sleeping clock and every independent ground world")
        desktop.activateSharedHome(now:date());tick(1.1)
        check(desktop.homeOccupants.isEmpty && desktop.actors.allSatisfy{$0.panel.isVisible},
              "one occupied-house click wakes all active friends without creating extra homes")
        let voiced = expansion.filter { !desktop.expansions[$0]!.catalog.clips.isEmpty }
        for friend in expansion {desktop.expansions[friend]!.previewVoice()}
        check(expansion.filter { !voiced.contains($0) }.allSatisfy { desktop.expansions[$0]!.voice.player == nil },
              "friends without verified recordings stay silent during a group preview")
        if let first=voiced.first {
            desktop.expansions[first]!.command(.stopVoice)
            check(desktop.expansions[first]!.voice.player==nil && voiced.dropFirst().allSatisfy{desktop.expansions[$0]!.voice.player != nil},
                  "stopping one new friend's audio leaves every other local voice player independent")
        }
        desktop.expansions.values.forEach{$0.voice.stop()}
    }
}

private extension NSRect { var center: NSPoint { NSPoint(x:midX,y:midY) } }
