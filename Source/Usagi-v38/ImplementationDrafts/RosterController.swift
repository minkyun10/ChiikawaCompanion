import AppKit

/// One complete independent world per new companion. Hachiware and Chiikawa keep
/// their reviewed systems; the expansion cast shares behavior, never mutable state.
final class RosterCompanion {
    unowned let desktop: DesktopController
    unowned let actor: FriendActor
    var friend: Friend { actor.friend }
    var state: AppState { desktop.state }
    var world = PropWorld<RosterProp>()
    var objects: [RosterProp: DesktopPropWindow<RosterProp>] = [:]
    var activities = ActivitySpotWorld()
    var spots: [ActivitySpot: DesktopActivitySpot] = [:]
    var activeSpot: ActivitySpot?
    var action: RosterAction?
    var actionStarted = Date.distantPast
    var actionUntil = Date.distantPast
    var queuedAction: RosterAction?
    var nextPerformance = Date.distantFuture
    var itemTarget: RosterProp?
    var wakingAt: Date?
    let voice: RecordedVoicePlayer
    var lastDialogueID: String?
    var lastVoiceID: String?
    var status = RosterStatus()
    var options: RosterOptions { state.options(for: friend) }
    var home: HomeRoutine {
        get { desktop.homeRoutines[friend] ?? HomeRoutine(now: desktop.started) }
        set { desktop.homeRoutines[friend] = newValue }
    }
    var usableFrame: NSRect {
        let screen = actor.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0,y: 0,width: 1280,height: 720)
        return screen.insetBy(dx: 0, dy: 0)
    }
    var propFrame: NSRect {
        var frame = usableFrame
        frame.size.height -= max(0, actor.panel.frame.height - 150)
        return frame
    }
    var catalog: RecordingCatalog { RosterRecordingCatalog.catalog(for: friend) }

    init(desktop: DesktopController, actor: FriendActor,
         voice: RecordedVoicePlayer = RecordedVoicePlayer(idleStatus: "클릭할 때만 녹음을 재생해요")) {
        self.desktop = desktop; self.actor = actor; self.voice = voice
        desktop.homeRoutines[actor.friend] = HomeRoutine(now: desktop.started)
        for kind in RosterItemKind.allCases {
            let item = RosterProp(owner: actor.friend, kind: kind), object = DesktopPropWindow(item: RosterProp(owner: actor.friend, kind: kind))
            object.view.onSeek = { [weak self] in self?.seek(kind) }
            object.view.onMove = { [weak self] point in
                guard let self else { return }
                self.world.move(item, to: point, bounds: self.propFrame)
                if self.world.requested == item { self.actor.motion.retarget() }
            }
            object.view.onMoveEnd = { [weak self] point in _ = self?.receive(kind, at: point) }
            objects[item] = object
        }
        for spot in ActivitySpot.allCases {
            let object = DesktopActivitySpot(spot: spot, owner: actor.friend)
            object.view.onSeek = { [weak self] in self?.visit(spot) }
            object.view.onMove = { [weak self] point in
                guard let self else { return }
                if self.activeSpot == spot { self.stopAction() }
                self.activities.move(spot, to: point, bounds: self.propFrame)
                if self.activities.requested == spot { self.actor.motion.retarget() }
            }
            object.view.onMoveEnd = { [weak self] in _ = self?.triggerActivity(now: Date()) }
            spots[spot] = object
        }
        actor.view.onRosterAction = { [weak self] action in self?.play(action) }
        actor.view.onStopDailyAction = { [weak self] in self?.stopAction() }
        actor.view.onDropEquipment = { [weak self] in self?.drop() }
        actor.view.onGoHome = { [weak self] in self?.goHome() }
        voice.onStatus = { [weak self] message in
            guard let self else { return }; self.status.voice = message; self.publish()
        }
        configure()
    }
    func close() {
        voice.stop(); objects.values.forEach { $0.panel.close() }; spots.values.forEach { $0.panel.close() }
    }
    func configure() {
        world.configure(enabled: Set(options.items.map { RosterProp(owner: friend, kind: $0) }), bounds: propFrame)
        let added = options.spots.subtracting(activities.enabled)
        activities.configure(enabled: options.spots, bounds: propFrame)
        let offset = CGFloat(Friend.expansionOrder.firstIndex(of: friend) ?? 0)
        for spot in added {
            let fraction: (CGFloat,CGFloat) = spot == .desk ? (0.12 + offset * 0.19,0.78) : spot == .rice ? (0.67 + offset * 0.08,0.23 + offset * 0.13) : (0.35 + offset * 0.12,0.39)
            let origin = RoamingMotion.target(in: usableFrame, size: actor.panel.frame.size, xFraction: fraction.0, yFraction: fraction.1)
            activities.move(spot, to: ItemWorld.contactPoint(origin: origin), bounds: propFrame)
        }
        if let activeSpot, !options.spots.contains(activeSpot) { stopAction() }
    }
    func publish() {
        status.equipped = world.equipped?.kind
        status.home = wakingAt == nil ? home.status : "일어나 기지개를 켜요"
        status.resting = home.isInside || wakingAt != nil
        status.actionRunning = action != nil
        state.publish(friend, status)
    }
    func command(_ command: RosterCommand) {
        switch command {
        case .seek(let kind): seek(kind)
        case .drop: drop()
        case .scatter: world.scatter(in: propFrame); world.requested = nil; itemTarget = nil; actor.motion.retarget()
        case .visit(let spot): visit(spot)
        case .action(let action): play(action)
        case .stopAction: stopAction()
        case .home: goHome()
        case .wake: wake(animated: true)
        case .voicePreview: previewVoice()
        case .stopVoice: voice.stop(); status.voice = "목소리 재생을 멈췄어요"; publish()
        }
    }
    func makeVisibleAndWalking() {
        state.showFriends = true; state.visibleFriends.insert(friend)
        state.roaming = true; state.walkingFriends.insert(friend)
    }
    func seek(_ kind: RosterItemKind, now: Date = Date()) {
        let item = RosterProp(owner: friend, kind: kind)
        guard world.ground[item] != nil else { return }
        wake(now: now); stopAction(); voice.stop(); makeVisibleAndWalking()
        actor.dismissBubble(); activities.requested = nil; world.requested = item; itemTarget = nil
        actor.motion.retarget(); status.item = "\(item.name) 주우러 가요"; publish()
    }
    func visit(_ spot: ActivitySpot, now: Date = Date()) {
        guard activities.positions[spot] != nil else { return }
        wake(now: now); stopAction(); voice.stop(); makeVisibleAndWalking()
        actor.dismissBubble(); world.requested = nil; itemTarget = nil
        activities.requested = spot; actor.motion.retarget()
        status.action = "\(spot.name)까지 걸어가요"; publish()
    }
    func play(_ selected: RosterAction, at spot: ActivitySpot? = nil, now: Date = Date()) {
        wake(now: now); actor.dismissBubble(); actor.motion.stop()
        action = selected; actionStarted = now; actionUntil = now.addingTimeInterval(selected.duration)
        queuedAction = nil; activeSpot = spot; activities.requested = nil
        world.requested = nil; itemTarget = nil
        if let spot { activities.consume(spot, now: now) }
        status.action = selected.title; publish()
    }
    func stopAction() {
        action = nil; queuedAction = nil; activeSpot = nil; actionUntil = .distantPast
        actor.motion.retarget(); status.action = "다시 산책해요"; publish()
    }
    @discardableResult
    func triggerActivity(now: Date) -> Bool {
        guard !actor.view.isDragging, now >= actor.bubbleUntil, action == nil,
              home.phase == .outside, world.requested == nil else { return false }
        activities.observe(contact: ItemWorld.contactPoint(origin: actor.panel.frame.origin))
        let dragged = Set(spots.filter { $0.value.view.isDragging }.map(\.key))
        guard let spot = activities.encounter(contact: ItemWorld.contactPoint(origin: actor.panel.frame.origin),
            automatic: options.automaticActivities, now: now, excluding: dragged) else { return false }
        if !activities.hasArrived(at: spot, contact: ItemWorld.contactPoint(origin: actor.panel.frame.origin)) {
            guard state.isWalking(friend) else { return false }
            if activities.requested != spot { activities.requested = spot; actor.motion.retarget() }
            return false
        }
        play(RosterAction(spot: spot), at: spot, now: now); return true
    }
    func drop(now: Date = Date()) {
        stopAction()
        let contact = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
        world.drop(at: NSPoint(x: contact.x + 88,y: contact.y), bounds: propFrame, now: now)
        world.requested = nil; itemTarget = nil; actor.motion.retarget(); status.item = "소품을 내려놓았어요"; publish()
    }
    @discardableResult
    func receive(_ kind: RosterItemKind, at point: NSPoint, now: Date = Date()) -> Bool {
        let item = RosterProp(owner: friend, kind: kind)
        guard state.isVisible(friend), actor.panel.isVisible, !actor.view.isDragging,
              options.items.contains(kind), DesktopGeometry.hit(point, in: actor.panel.frame),
              world.equip(item, at: actor.panel.frame.origin, bounds: propFrame, now: now) else { return false }
        pickedUp(item, now: now); return true
    }
    func pickedUp(_ item: RosterProp, now: Date) {
        stopAction(); activities.requested = nil; itemTarget = nil; actor.motion.retarget()
        action = .pickup; actionStarted = now; actionUntil = now.addingTimeInterval(0.65)
        queuedAction = item.kind == .camera ? .camera : item.kind == .guitar ? .guitar : item.kind == .keepsake ? .keepsake : nil
        nextPerformance = now.addingTimeInterval(18)
        status.item = "\(item.kind.name(for: friend))와 함께해요"; publish()
    }
    func goHome(now: Date = Date()) {
        stopAction(); voice.stop(); actor.dismissBubble(); makeVisibleAndWalking()
        activities.requested = nil; world.requested = nil; itemTarget = nil
        wakingAt = nil; home.request(now: now); actor.motion.retarget(); publish()
    }
    func wake(now: Date = Date(), animated: Bool = false) {
        let wasInside = home.isInside
        if home.phase != .outside || wakingAt != nil { home.wake(now: now) }
        wakingAt = animated && wasInside ? now : nil
        if wasInside && !animated {
            // Exit at the door only when waking, never during free roaming.
            let origin = ItemWorld.destination(for: NSPoint(x: desktop.home.entrance.x + 35,y: desktop.home.entrance.y))
            actor.panel.setFrameOrigin(DesktopGeometry.clamp(origin, size: actor.panel.frame.size, to: usableFrame))
        }
        actor.motion.retarget(); publish()
    }
    @discardableResult
    func enterHome(now: Date) -> Bool {
        guard action == nil, !actor.view.isDragging, now >= actor.bubbleUntil, activities.requested == nil,
              home.arrive(contact: ItemWorld.contactPoint(origin: actor.panel.frame.origin), entrance: desktop.home.entrance, now: now) else { return false }
        world.drop(at: NSPoint(x: desktop.home.panel.frame.maxX + 24,y: desktop.home.entrance.y), bounds: propFrame, now: now)
        world.requested = nil; itemTarget = nil; actor.motion.stop(); actor.panel.orderOut(nil)
        actor.armedHoverContact = nil; actor.wasHovered = false; voice.stop(); publish(); return true
    }
    func beganDragging() {
        voice.stop(); stopAction(); actor.dismissBubble()
        if home.phase != .outside { wake() }
        activities.requested = nil; world.requested = nil; itemTarget = nil
    }
    func endedDragging(now: Date = Date()) {
        actor.motion.retarget(); itemTarget = nil
        if triggerActivity(now: now) { return }
        if hypot(ItemWorld.contactPoint(origin: actor.panel.frame.origin).x - desktop.home.entrance.x,
                 ItemWorld.contactPoint(origin: actor.panel.frame.origin).y - desktop.home.entrance.y) <= 24 {
            home.request(now: now); _ = enterHome(now: now)
        }
    }
    func clicked(now: Date = Date()) {
        wake(now: now); stopAction(); actor.motion.stop()
        let recordings = catalog.clips.map { ClickDialogue(id: "voice-\($0.id)",text: $0.text,recording: $0) }
        let texts = friend.reactionTexts.enumerated().map { ClickDialogue(id: "reaction-\($0.offset)",text: $0.element,recording: nil) }
        guard let chosen = (recordings + texts).filter({ $0.id != lastDialogueID }).randomElement() else { return }
        lastDialogueID = chosen.id; voice.stop()
        actor.say(chosen.text, now: now, duration: max(2.4,(chosen.recording?.duration ?? 0) + 0.35))
        if options.voice, let recording = chosen.recording { _ = voice.play(recording, volume: state.characterVolume) }
        status.voice = chosen.recording == nil ? "클릭 반응 · \(chosen.text)" : "\(friend.voiceActor) 성우 녹음"; publish()
    }
    func previewVoice() {
        guard let chosen = catalog.choose(excluding: lastVoiceID) else { status.voice = "공개 캐릭터 녹음을 아직 등록하지 못했어요"; publish(); return }
        lastVoiceID = chosen.id; _ = voice.play(chosen, volume: state.characterVolume)
    }
    func updateObjects(visible: Bool, mouse: NSPoint) {
        for (item, object) in objects { object.update(position: world.ground[item], visible: visible, mouse: mouse) }
        for (spot, object) in spots {
            object.update(position: activities.positions[spot], visible: visible && (activeSpot != spot || spot == .furball),
                mouse: mouse, behind: actor.panel.isVisible ? actor.panel.windowNumber : nil)
        }
    }
    func tick(now: Date, dt: TimeInterval, time: Double, mouse: NSPoint, pointerCanReachCharacter: Bool?) {
        configure(); voice.setVolume(state.characterVolume)
        if !options.voice { voice.stop() }
        guard state.isVisible(friend) else {
            voice.stop(); stopAction(); wake(now: now); actor.dismissBubble(); actor.panel.orderOut(nil)
            actor.motion.stop(); actor.wasHovered = false; actor.armedHoverContact = nil
            actor.view.action = nil; actor.view.rosterVisual = nil; updateObjects(visible: false,mouse: mouse); return
        }
        home.advance(now: now)
        if home.shouldWake(now: now) { wake(now: now, animated: true) }
        if let began = wakingAt, now.timeIntervalSince(began) >= 0.96 { wakingAt = nil
            let origin = ItemWorld.destination(for: NSPoint(x: desktop.home.entrance.x + 35,y: desktop.home.entrance.y))
            actor.panel.setFrameOrigin(DesktopGeometry.clamp(origin,size: actor.panel.frame.size,to: usableFrame)); actor.motion.retarget()
        }
        if !home.isInside && wakingAt == nil { _ = enterHome(now: now) }
        if home.isInside || wakingAt != nil {
            actor.panel.orderOut(nil); actor.motion.stop(); updateObjects(visible: true,mouse: mouse); publish(); return
        }
        if !actor.panel.isVisible { actor.panel.orderFrontRegardless() }
        let hovered = actor.pointerIsHovering(at: mouse,armed: state.expressive && world.equipped?.kind == .weapon,canReach: pointerCanReachCharacter)
        actor.panel.ignoresMouseEvents = !hovered && !actor.view.isDragging
        if hovered && !actor.wasHovered { actor.hoverStarted = now }
        actor.wasHovered = hovered
        let activity = DesktopActivity.resolve(roaming: state.isWalking(friend),hovered: hovered,dragging: actor.view.isDragging,dialogueUntil: actor.bubbleUntil,now: now)
        if action != nil && now >= actionUntil {
            if let queued = queuedAction { action = queued; queuedAction = nil; actionStarted = now; actionUntil = now.addingTimeInterval(queued.duration) }
            else { stopAction() }
        }
        let attacking = activity == .hovering && state.expressive && world.equipped?.kind == .weapon
        if attacking && action != nil { stopAction() }
        if activity == .dragging || activity == .speaking { if action != nil { stopAction() } }
        if activity == .walking || activity == .idle { _ = triggerActivity(now: now) }
        if activity == .walking, action == nil, activities.requested == nil, world.requested == nil,
           home.shouldReturn(now: now,automatic: options.automaticRest,roaming: state.isWalking(friend)) { goHome(now: now) }
        if activity == .walking && action == nil {
            let start = actor.panel.frame
            let dragged = Set(objects.filter { $0.value.view.isDragging }.map(\.key))
            let following = home.phase == .returning || activities.requested != nil
            let target = following ? nil : world.nearbyTarget(from: start.origin,automatic: options.automaticItems,now: now,excluding: dragged)
                ?? world.target(from: start.origin,automatic: options.automaticItems,now: now,excluding: dragged)
            if itemTarget != target { itemTarget = target; actor.motion.retarget() }
            if home.phase == .returning { actor.motion.destination = ItemWorld.destination(for: desktop.home.entrance) }
            else if let spot = activities.requested, let point = activities.positions[spot] { actor.motion.destination = ItemWorld.destination(for: point) }
            else if let target, let point = world.ground[target] {
                actor.motion.destination = ItemWorld.destination(for: point)
                if world.pickUp(target,from: start.origin,bounds: propFrame,now: now) { pickedUp(target,now: now) }
            }
            if actor.motion.destination == nil && action == nil {
                var target = start.origin
                for _ in 0..<8 {
                    target = RoamingMotion.target(in: usableFrame,size: start.size,xFraction: .random(in: 0.04...0.96),yFraction: .random(in: 0.04...0.96))
                    if hypot(target.x-start.minX,target.y-start.minY) > min(usableFrame.width,usableFrame.height)*0.28 { break }
                }
                actor.motion.destination = target
            }
            if action == nil {
                actor.panel.setFrameOrigin(actor.motion.advance(from: start.origin,dt: dt,bounds: usableFrame,size: start.size,
                    stoppingDistance: activities.requested == nil ? 5 : ActivitySpotWorld.stoppingDistance))
                actor.gait.recordMovement(from: start.origin,to: actor.panel.frame.origin)
            } else { actor.motion.stop() }
            _ = enterHome(now: now)
            if !home.isInside { _ = triggerActivity(now: now) }
            if !following, action == nil, !home.isInside,
               let nearby = world.nearbyTarget(from: actor.panel.frame.origin,automatic: options.automaticItems,now: now,excluding: dragged),
               world.pickUp(nearby,from: actor.panel.frame.origin,bounds: propFrame,now: now) { pickedUp(nearby,now: now) }
            if !following, action == nil, state.expressive, now >= nextPerformance, let equipped = world.equipped {
                let selected: RosterAction? = equipped.kind == .camera ? .camera : equipped.kind == .guitar ? .guitar : equipped.kind == .keepsake ? .keepsake : nil
                if let selected { action = selected; actionStarted = now; actionUntil = now.addingTimeInterval(selected.duration); actor.motion.stop() }
                nextPerformance = now.addingTimeInterval(20)
            }
        } else { actor.motion.stop() }
        let shown: RosterAction? = attacking ? .attack : activity == .speaking ? .surprised
            : activity == .hovering && state.expressive ? now.timeIntervalSince(actor.hoverStarted) < 0.3 ? .wave : .laugh : action
        if shown == .attack && actor.view.action != .attack { actor.hoverStarted = now }
        actor.view.time = time + actor.phase; actor.view.walking = actor.motion.isWalking
        actor.view.walkPhase = actor.gait.phase; actor.view.facing = actor.motion.facing
        actor.view.pose = HachiwarePose.forVelocity(actor.motion.velocity)
        actor.view.happy = activity.reacts && shown != .attack
        actor.view.action = shown == .attack ? .attack : nil
        let elapsed = shown == .attack ? max(0,now.timeIntervalSince(actor.hoverStarted)) : action == shown ? max(0,now.timeIntervalSince(actionStarted)) : max(0,now.timeIntervalSince(actor.hoverStarted))
        actor.view.actionTime = shown == .attack ? elapsed : nil
        actor.view.rosterVisual = RosterVisual(action: shown,elapsed: elapsed,equipped: world.equipped?.kind,happy: activity.reacts)
        actor.view.needsDisplay = true
        if now < actor.bubbleUntil { actor.positionBubble() } else if actor.bubble != nil { actor.dismissBubble() }
        updateObjects(visible: true,mouse: mouse); publish()
    }
}

enum RosterRecordingCatalog {
    private static var cached: [Friend: RecordingCatalog] = [:]
    static func catalog(for friend: Friend) -> RecordingCatalog {
        if let catalog = cached[friend] { return catalog }
        let catalog = RecordingCatalog.load("\(friend.rawValue)-recordings-v38.json",speaker: friend.voiceActor)
        cached[friend] = catalog; return catalog
    }
}
