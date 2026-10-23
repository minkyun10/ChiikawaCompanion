import AppKit
import CryptoKit

extension SelfTest {
    static func runMonsterChecks(check: (Bool,String)->Void) {
        var trigger = HachiwareTransformation()
        check((0..<4).allSatisfy { !trigger.click(at:Double($0)*2) } && !trigger.isMonster,
              "monster transform requires five distinct completed clicks")
        check(trigger.click(at:10) && trigger.isMonster && trigger.clicks.isEmpty,
              "the fifth click at the inclusive ten-second boundary transforms and consumes the window")
        check(!trigger.click(at:10.1) && trigger.isMonster,"a sixth click does not immediately transform back")
        for time in [11.0,12,13] { _ = trigger.click(at:time) }
        check(trigger.click(at:14) && !trigger.isMonster,"another complete five-click window restores normal Hachiware")
        check(trigger.progress(at:14) == 0 && trigger.progress(at:14.325) > 0.49 && trigger.progress(at:15) == 1,
              "transformation uses one bounded 650ms crossfade")
        var expired = HachiwareTransformation()
        for time in [0.0,1,2,3] { _ = expired.click(at:time) }
        check(!expired.click(at:10.01) && expired.clicks.count == 4,"expired oldest clicks cannot trigger a late transformation")
        check(expired.click(at:10.5),"five still-valid clicks in the rolling window transform")
        expired.interruptSequence(); _ = expired.click(at:20)
        check(!expired.click(at:19) && expired.clicks == [19],"clock reversal starts a new click sequence")
        check(!expired.click(at:.nan) && expired.clicks.isEmpty,"invalid timestamps never accumulate")
        var rapid = HachiwareTransformation()
        for n in 0..<5 { _ = rapid.click(at:Double(n)*0.01) }
        let beforeReverse = rapid.monsterOpacity(at:0.14)
        for n in 0..<5 { _ = rapid.click(at:0.10+Double(n)*0.01) }
        check(abs(rapid.monsterOpacity(at:0.14)-beforeReverse)<0.000001 && rapid.monsterOpacity(at:1)==0,
              "rapid repeat transformation reverses from the visible blend without an artwork pop")

        let sprites = HachiwareMonsterSprites.shared
        check(sprites.isReady,"monster has all eight 24-frame walks, eleven 12-frame actions and sleeping frames")
        if Bundle.main.bundleURL.pathExtension == "app" {
            check(sprites.usesBundledAtlases,"packaged monster decodes prebuilt atlases without rig rendering")
        }
        func hash(_ image: NSImage) -> String { SHA256.hash(data:image.tiffRepresentation!).map { String(format:"%02x",$0) }.joined() }
        for direction in ChiikawaDirection.allCases {
            check(Set(sprites.walks[direction]!.map(hash)).count == 24,"\(direction.rawValue) contains twenty-four chronological, nonduplicate monster walk drawings")
        }
        var symmetric = true
        for index in 0..<24 {
            let phase = Double(index)/24
            let right = HachiwareMonsterRig.footPose(phase+0.5), same = HachiwareMonsterRig.footPose(phase-0.5)
            symmetric = symmetric && abs(right.travel-same.travel)<0.000001 && abs(right.lift-same.lift)<0.000001 && abs(right.angle-same.angle)<0.000001
        }
        check(symmetric,"both monster feet follow the same stance/swing path with an exact half-cycle offset")
        check(Set(sprites.sleeping.map(hash)).count > 1,"monster sleep includes anchored breathing instead of a static normal-character fallback")
        let body = NSRect(x:0,y:0,width:132,height:150)
        let registration = sprites.registration!
        let destinations = (0..<12).map { registration.destination(frame:$0,in:body) }
        check(destinations.allSatisfy { abs($0.width-440*132/256)<0.000001 && abs($0.height-132)<0.000001 },
              "monster attack retains the walking body scale in every frame")
        check(registration.extent(in:body).width>body.width,"the monster spear uses a separate wide viewport")
        var allActionFramesNonempty = true
        for action in HachiwareAction.allCases {
            allActionFramesNonempty = allActionFramesNonempty && sprites.actions[action]!.allSatisfy {
                guard let data=$0.tiffRepresentation,let rep=NSBitmapImageRep(data:data) else {return false}
                return (0..<rep.pixelsHigh).contains { y in (0..<rep.pixelsWide).contains { x in
                    (rep.colorAt(x:x,y:y)?.alphaComponent ?? 0)>0.5
                } }
            }
        }
        check(allActionFramesNonempty,"every monster action frame contains its own artwork, including camera/guitar/weapon/study/eat/vomit")
        let walkingMask = ArmedPointerArtwork.shared.walking(.hachiware,pose:.front,facing:-1,monster:true,armed:false)
        let attackMask = ArmedPointerArtwork.shared.attack(.hachiware,monster:true)
        check(walkingMask.contains(NSPoint(x:66,y:75)) && attackMask.contains(NSPoint(x:66,y:75)),
              "monster body stays a pointer target in walking and attack poses")

        let suite = "MonsterChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let state = AppState(defaults:defaults)
        state.characterVoice = false; state.chiikawaVoice = false
        state.visibleFriends = [.hachiware,.chiikawa]; state.automaticRest = false; state.chiikawaAutomaticRest = false
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.automaticActivities = false; state.chiikawaAutomaticActivities = false
        state.enabledItems = [.sasumata]; state.enabledActivitySpots = []
        let desktop = DesktopController(state:state,startTimer:false)
        defer {
            desktop.actors.forEach { $0.dismissBubble();$0.panel.orderOut(nil);$0.attackOverlay.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil)
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
        }
        let actor = desktop.hachiwareActor!, bounds = NSScreen.main!.visibleFrame
        actor.panel.setFrameOrigin(RoamingMotion.target(in:bounds,size:actor.panel.frame.size,xFraction:0.4,yFraction:0.65))
        desktop.itemWorld.move(.sasumata,to:ItemWorld.contactPoint(origin:actor.panel.frame.origin),bounds:bounds)
        check(desktop.itemWorld.pickUp(.sasumata,from:actor.panel.frame.origin,bounds:bounds,now:Date()),"monster fixture starts with Hachiware's existing equipped weapon")
        actor.gait.recordMovement(from:.zero,to:NSPoint(x:31,y:0))
        actor.motion.destination = NSPoint(x:bounds.midX,y:bounds.midY)
        let frame = actor.panel.frame, phase = actor.gait.phase, destination = actor.motion.destination, ground = desktop.itemWorld.ground
        for index in 0..<5 {
            let event = NSEvent.mouseEvent(with:.leftMouseDown,location:.zero,modifierFlags:[],timestamp:Double(index),
                windowNumber:actor.panel.windowNumber,context:nil,eventNumber:index,clickCount:index+1,pressure:1)!
            actor.view.mouseDown(with:event); actor.view.mouseUp(with:event)
        }
        check(desktop.hachiwareTransformation.isMonster && actor.view.hachiwareMonster,
              "five actual view mouse-down/up pairs transform despite the shared drag-start callback")
        check(actor.panel.frame == frame && actor.gait.phase == phase && actor.motion.destination == destination,
              "transformation preserves desktop origin, actor size, current route and distance-based gait")
        check(desktop.itemWorld.equipped == .sasumata && desktop.itemWorld.ground == ground,
              "transformation keeps equipment and independent ground-item coordinates")
        check(desktop.chiikawaActor?.view.hachiwareMonster == false,"other companions never inherit the monster form")
        actor.view.transformationProgress = 1; actor.view.action = .attack; actor.panel.orderFrontRegardless()
        actor.attackOverlay.update(actor:actor)
        check(actor.attackOverlay.view.hachiwareMonster && actor.view.attackUsesOverlay,
              "armed hover overlay selects the monster attack instead of the original Hachiware atlas")
        actor.view.action = nil; actor.attackOverlay.update(actor:actor)
        for index in 0..<4 { desktop.handleCharacterClick(actor,monotonicTime:100+Double(index)) }
        desktop.handleCharacterClick(desktop.chiikawaActor!,monotonicTime:104)
        check(desktop.hachiwareTransformation.clicks.isEmpty,"clicking another character breaks the consecutive Hachiware sequence")
        for index in 0..<4 { desktop.handleCharacterClick(actor,monotonicTime:110+Double(index)) }
        actor.view.onDragEnd?()
        check(desktop.hachiwareTransformation.clicks.isEmpty,"dragging Hachiware breaks the five-click sequence")
        var rest = HomeRoutine(now:Date())
        rest.request(now:Date()); _ = rest.arrive(contact:desktop.home.entrance,entrance:desktop.home.entrance,now:Date())
        desktop.homeRoutines[.hachiware] = rest
        check(desktop.homeOccupants.contains { $0.friend == .hachiware && $0.hachiwareMonster },
              "the single shared house retains the monster identity during entering and sleep")
        desktop.homeRoutines[.hachiware] = HomeRoutine(now:Date())
        for index in 0..<5 { desktop.handleCharacterClick(actor,monotonicTime:120+Double(index)) }
        check(!desktop.hachiwareTransformation.isMonster && !actor.view.hachiwareMonster,
              "the live controller restores normal artwork after a second full five-click sequence")
    }
}
