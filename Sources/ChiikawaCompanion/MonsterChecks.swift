import AppKit
import CryptoKit

extension SelfTest {
    static func runMonsterChecks(check: (Bool,String)->Void) {
        var trigger = HachiwareTransformation()
        check((0..<4).allSatisfy { !trigger.click(at:Double($0)*2) } && !trigger.isMonster,
              "monster transform requires five distinct completed clicks")
        check(trigger.click(at:10) && trigger.isMonster && trigger.clicks.isEmpty,
              "the fifth click at the inclusive ten-second boundary transforms and consumes the window")
        check(trigger.scale(at:10) == 1 && abs(trigger.scale(at:10.325)-5.5)<0.000001 && trigger.scale(at:11)==10,
              "monster grows smoothly from one to ten times width and height over the existing crossfade")
        check(trigger.returnsAt == 40,"the fifth click starts one thirty-second monster lifetime")
        for time in [10.1,11,12,13,39.9] { _ = trigger.click(at:time) }
        check(trigger.isMonster && trigger.clicks.isEmpty && trigger.returnsAt == 40,
              "clicks in monster form neither toggle back nor extend the return deadline")
        check(!trigger.advance(at:39.999) && trigger.isMonster,"automatic return cannot fire before its deadline")
        check(trigger.advance(at:40) && !trigger.isMonster && trigger.returnsAt == nil && trigger.clicks.isEmpty,
              "the inclusive thirty-second deadline returns exactly once and clears pending clicks")
        check(trigger.progress(at:40) == 0 && trigger.progress(at:40.325) > 0.49 && trigger.progress(at:41) == 1,
              "automatic return uses one bounded 650ms crossfade")
        check(trigger.monsterOpacity(at:40) == 1 && abs(trigger.monsterOpacity(at:40.325)-0.5)<0.000001
              && trigger.monsterOpacity(at:41) == 0,"the return fade begins at the visible monster and ends at normal artwork")
        check(trigger.scale(at:40) == 10 && abs(trigger.scale(at:40.325)-5.5)<0.000001 && trigger.scale(at:41)==1,
              "automatic return smoothly shrinks from ten times to normal size")
        let logical=NSRect(x:-600,y:240,width:132,height:150)
        let huge=CharacterScaleGeometry.frame(for:logical,scale:10)
        check(huge.size == NSSize(width:1320,height:1500)
              && abs(huge.midX-logical.midX)<0.000001
              && abs(huge.minY+ItemWorld.contactOffset.y*10-(logical.minY+ItemWorld.contactOffset.y))<0.000001,
              "giant geometry preserves the same ground contact on negative-coordinate displays without fitting to screen height")
        var giantGait=WalkingGait()
        giantGait.recordMovement(from:.zero,to:NSPoint(x:627,y:0),artworkScale:10)
        check(abs(giantGait.phase-2 * .pi)<0.000001,"ten-times larger feet take one gait cycle per ten-times larger actual stride")
        check(!trigger.advance(at:41),"later ticks never restart a completed return fade")
        for n in 0..<5 { _ = trigger.click(at:42+Double(n)) }
        check(trigger.isMonster && trigger.returnsAt == 76,"a fresh five-click sequence can transform again after automatic return")
        check(!trigger.advance(at:.nan) && !trigger.advance(at:.infinity) && trigger.isMonster,
              "invalid timer timestamps cannot end or corrupt an active transformation")
        check(trigger.advance(at:1000) && trigger.monsterOpacity(at:1000) == 1 && trigger.progress(at:1000)==0,
              "a delayed tick starts the return fade when rendering resumes instead of skipping it")
        var expired = HachiwareTransformation()
        for time in [0.0,1,2,3] { _ = expired.click(at:time) }
        check(!expired.click(at:10.01) && expired.clicks.count == 4,"expired oldest clicks cannot trigger a late transformation")
        check(expired.click(at:10.5),"five still-valid clicks in the rolling window transform")
        _ = expired.advance(at:41)
        expired.interruptSequence(); _ = expired.click(at:50)
        check(!expired.click(at:49) && expired.clicks == [49],"clock reversal starts a new click sequence")
        check(!expired.click(at:.nan) && expired.clicks.isEmpty,"invalid timestamps never accumulate")

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
              "the fifth click preserves the ground anchor, route and gait before gradual growth begins")
        check(desktop.itemWorld.equipped == .sasumata && desktop.itemWorld.ground == ground,
              "transformation keeps equipment and independent ground-item coordinates")
        check(desktop.chiikawaActor?.view.hachiwareMonster == false,"other companions never inherit the monster form")
        _ = desktop.updateHachiwareTransformation(at:desktop.hachiwareTransformation.returnsAt!-29)
        check(actor.panel.frame.size == NSSize(width:1320,height:1500)
              && actor.view.bounds.size == actor.panel.frame.size && actor.movementFrame == frame,
              "completed monster transformation is exactly ten times wider and taller with an unchanged logical footprint")
        let giantCenter=NSPoint(x:actor.panel.frame.midX,y:actor.panel.frame.midY)
        check(!actor.movementFrame.contains(giantCenter) && actor.pointerIsHovering(at:giantCenter,armed:false,canReach:true),
              "visible giant body outside the old small rectangle receives hover at its actual scaled position")
        let anchor=actor.movementFrame
        for n in 0...60 { actor.setPresentationScale(1+9*CGFloat(n)/60) }
        for n in 0...60 { actor.setPresentationScale(10-9*CGFloat(n)/60) }
        check(actor.movementFrame == anchor && actor.panel.frame.size == Friend.hachiware.actorSize,
              "repeated native growth/shrink updates do not accumulate anchor rounding or size drift")
        actor.setPresentationScale(10)
        let visualOrigin=actor.panel.frame.origin
        actor.panel.setFrameOrigin(NSPoint(x:visualOrigin.x+24,y:visualOrigin.y+12))
        check(abs(actor.movementFrame.minX-anchor.minX-24)<0.01 && abs(actor.movementFrame.minY-anchor.minY-12)<0.01,
              "native window drag translation moves the logical ground contact by the same distance")
        actor.setMovementOrigin(anchor.origin)
        check(actor.movementFrame == anchor && desktop.itemWorld.ground == ground,
              "repositioning a giant preserves the footprint and independent ground props")
        actor.view.action = .attack; actor.panel.orderFrontRegardless()
        actor.attackOverlay.update(actor:actor)
        check(actor.attackOverlay.view.hachiwareMonster && actor.view.attackUsesOverlay,
              "armed hover overlay selects the monster attack instead of the original Hachiware atlas")
        check(actor.attackOverlay.view.body.size == NSSize(width:1320,height:1500),
              "the actual attack overlay receives the same ten-times body size instead of shrinking the giant")
        actor.view.action = nil; actor.attackOverlay.update(actor:actor)
        let deadline = desktop.hachiwareTransformation.returnsAt!
        for index in 0..<8 { desktop.handleCharacterClick(actor,monotonicTime:deadline-1+Double(index)*0.01) }
        check(desktop.hachiwareTransformation.isMonster && desktop.hachiwareTransformation.returnsAt == deadline,
              "live dialogue clicks during monster form leave its fixed deadline intact")
        actor.dismissBubble()
        let bubbleUntil = actor.bubbleUntil, dialogueID = desktop.lastClickDialogueID, voiceStatus = state.voiceStatus
        let returnFrame = actor.movementFrame, returnPhase = actor.gait.phase, returnDestination = actor.motion.destination
        actor.view.action = .attack; actor.view.actionTime = 0.4
        check(desktop.updateHachiwareTransformation(at:deadline) && !actor.view.hachiwareMonster,
              "the live controller starts automatic return at the deadline")
        check(actor.movementFrame == returnFrame && actor.gait.phase == returnPhase && actor.motion.destination == returnDestination
              && desktop.itemWorld.equipped == .sasumata && desktop.itemWorld.ground == ground,
              "automatic return preserves its ground anchor, gait, route, equipment and ground props while shrinking")
        check(actor.view.action == .attack && actor.view.actionTime == 0.4,
              "automatic return preserves the active attack and its animation time")
        check(actor.bubble == nil && actor.bubbleUntil == bubbleUntil && desktop.lastClickDialogueID == dialogueID
              && state.voiceStatus == voiceStatus && desktop.recordedVoice.player == nil,
              "automatic return creates no unsolicited bubble or sound and does not alter click dialogue")
        actor.attackOverlay.update(actor:actor)
        check(!actor.view.attackUsesOverlay && !actor.attackOverlay.panel.isVisible,
              "the attack overlay yields to the body crossfade while returning")
        _ = desktop.updateHachiwareTransformation(at:deadline+0.325)
        print("OBSERVATION: return midpoint window=\(actor.panel.frame.size), logical=\(actor.movementFrame), anchor=\(returnFrame)")
        check(abs(actor.panel.frame.width-726)<=1 && abs(actor.panel.frame.height-825)<=1 && actor.movementFrame == returnFrame,
              "the live return reaches the midpoint scale within native pixel rounding without moving its ground anchor")
        _ = desktop.updateHachiwareTransformation(at:deadline+1); actor.attackOverlay.update(actor:actor)
        check(actor.panel.frame.size == Friend.hachiware.actorSize && actor.movementFrame == returnFrame,
              "the return blend restores normal physical size at the same ground anchor")
        check(!actor.attackOverlay.view.hachiwareMonster && actor.view.attackUsesOverlay,
              "the existing attack resumes with normal artwork at the same body scale after the fade")
        actor.view.action = nil; actor.attackOverlay.update(actor:actor)
        for index in 0..<4 { desktop.handleCharacterClick(actor,monotonicTime:deadline+2+Double(index)) }
        desktop.handleCharacterClick(desktop.chiikawaActor!,monotonicTime:deadline+6)
        check(desktop.hachiwareTransformation.clicks.isEmpty,"clicking another character breaks the consecutive Hachiware sequence")
        for index in 0..<4 { desktop.handleCharacterClick(actor,monotonicTime:deadline+7+Double(index)) }
        actor.view.onDragEnd?()
        check(desktop.hachiwareTransformation.clicks.isEmpty,"dragging Hachiware breaks the five-click sequence")
        for index in 0..<5 { desktop.handleCharacterClick(actor,monotonicTime:deadline+12+Double(index)) }
        let sleepDeadline = desktop.hachiwareTransformation.returnsAt!
        _ = desktop.updateHachiwareTransformation(at:sleepDeadline-1)
        let now = Date()
        var rest = HomeRoutine(now:now)
        rest.request(now:now); _ = rest.arrive(contact:desktop.home.entrance,entrance:desktop.home.entrance,now:now)
        rest.advance(now:now.addingTimeInterval(HomeRoutine.entryDuration))
        desktop.homeRoutines[.hachiware] = rest
        actor.dismissBubble()
        check(desktop.homeOccupants.contains { $0.friend == .hachiware && $0.hachiwareMonster && $0.visibleMonsterOpacity == 1 },
              "the single shared house retains the monster identity and appearance during sleep")
        desktop.tick(now:now,pointer:NSPoint(x:-10000,y:-10000),pointerCanReachCharacter:false,monotonicTime:sleepDeadline)
        check(!desktop.hachiwareTransformation.isMonster && !actor.view.hachiwareMonster && desktop.homeRoutine.phase == .sleeping
              && !actor.panel.isVisible && desktop.homeOccupants.contains { $0.friend == .hachiware && !$0.hachiwareMonster },
              "the real tick returns a sleeping monster without waking it or moving its home")
        desktop.tick(now:now,pointer:NSPoint(x:-10000,y:-10000),pointerCanReachCharacter:false,monotonicTime:sleepDeadline+0.325)
        check(desktop.homeOccupants.contains { $0.friend == .hachiware && abs($0.visibleMonsterOpacity-0.5)<0.000001 },
              "sleeping artwork shares the same continuous 650ms return blend")
        desktop.tick(now:now,pointer:NSPoint(x:-10000,y:-10000),pointerCanReachCharacter:false,monotonicTime:sleepDeadline+1)
        check(desktop.homeOccupants.contains { $0.friend == .hachiware && $0.visibleMonsterOpacity == 0 },
              "the sleeping return reaches normal Hachiware without a residual monster frame")
        desktop.homeRoutines[.hachiware] = HomeRoutine(now:now)
        for index in 0..<5 { desktop.handleCharacterClick(actor,monotonicTime:sleepDeadline+2+Double(index)) }
        let walkingDeadline = desktop.hachiwareTransformation.returnsAt!
        state.roaming = true; state.walkingFriends.insert(.hachiware); state.expressive = false
        actor.dismissBubble(); actor.motion.destination = NSPoint(x:bounds.maxX-actor.movementFrame.width,y:bounds.maxY-actor.movementFrame.height)
        let walkingOrigin = actor.movementFrame.origin
        // AppKit may round the first sub-point displacement to zero. Check a
        // short continuous segment, as the existing roaming regression does.
        for index in 1...6 {
            desktop.tick(now:now.addingTimeInterval(Double(index)/60),pointer:NSPoint(x:-10000,y:-10000),
                         pointerCanReachCharacter:false,monotonicTime:walkingDeadline+Double(index-1)/60)
        }
        let moved = hypot(actor.movementFrame.minX-walkingOrigin.x,actor.movementFrame.minY-walkingOrigin.y)
        check(!desktop.hachiwareTransformation.isMonster && actor.motion.isWalking && moved>0 && moved<8,
              "walking continues through automatic return with only normal continuous displacement")
        for index in 0..<5 { desktop.handleCharacterClick(actor,monotonicTime:walkingDeadline+2+Double(index)) }
        let hiddenDeadline = desktop.hachiwareTransformation.returnsAt!
        state.visibleFriends.remove(.hachiware)
        desktop.tick(now:now,pointer:NSPoint(x:-10000,y:-10000),pointerCanReachCharacter:false,monotonicTime:hiddenDeadline)
        check(!desktop.hachiwareTransformation.isMonster && !actor.view.hachiwareMonster && !actor.panel.isVisible,
              "the return clock also advances while Hachiware is hidden")
    }
}
