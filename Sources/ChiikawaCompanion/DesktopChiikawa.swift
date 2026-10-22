import AppKit

extension DesktopController {
    func callFriend(_ friend: Friend) {
        guard let actor = actors.first(where: { $0.friend == friend }),
              let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        if let companion = expansions[friend] {
            companion.stopAction(); companion.voice.stop(); companion.wake()
            companion.world.requested = nil; companion.itemTarget = nil
        } else if friend == .hachiware {
            stopDailyAction(); stopCharacterVoice()
            if homeRoutine.phase != .outside { wakeFromHome() }
            itemTarget = nil
        } else {
            stopChiikawaLife(); stopChiikawaVoice()
            if chiikawaHomeRoutine.phase != .outside || chiikawaWakingAt != nil { wakeChiikawa() }
            chiikawaItemTarget = nil
        }
        state.showFriends = true; state.visibleFriends.insert(friend)
        actor.dismissBubble(); actor.motion.retarget()
        let index = Friend.developmentRoster.firstIndex(of: friend) ?? 0
        actor.panel.setFrameOrigin(RoamingMotion.target(in: screen.visibleFrame, size: actor.panel.frame.size,
            xFraction: 0.08 + CGFloat(index) * 0.84 / CGFloat(max(1, Friend.developmentRoster.count - 1)), yFraction: 0.28))
    }

    func configureChiikawaItems() {
        for item in ChiikawaItem.allCases {
            let object = DesktopPropWindow(item: item)
            object.view.onSeek = { [weak self] in self?.seekChiikawaItem(item) }
            object.view.onMove = { [weak self, weak object] point in
                guard let self, let bounds = (NSScreen.screens.first { $0.frame.contains(point) }
                    ?? object?.panel.screen ?? NSScreen.main)?.visibleFrame else { return }
                self.chiikawaWorld.move(item, to: point, bounds: bounds)
                if self.chiikawaWorld.requested == item { self.chiikawaActor?.motion.retarget() }
            }
            object.view.onMoveEnd = { [weak self] point in _ = self?.receiveChiikawaItem(item, at: point) }
            chiikawaDesktopItems[item] = object
        }
        state.onChiikawaSeekItem = { [weak self] item in self?.seekChiikawaItem(item) }
        state.onChiikawaDropItem = { [weak self] in self?.dropChiikawaItem() }
        state.onChiikawaScatterItems = { [weak self] in
            guard let self, let bounds = NSScreen.main?.visibleFrame else { return }
            self.chiikawaWorld.scatter(in: bounds); self.chiikawaItemTarget = nil
            self.chiikawaActor?.motion.retarget()
            self.state.chiikawaItemStatus = "치이카와 소품을 다시 놓았어요"
        }
    }
    func seekChiikawaItem(_ item: ChiikawaItem) {
        guard chiikawaWorld.ground[item] != nil else { return }
        stopChiikawaLife(); stopChiikawaVoice()
        if chiikawaHomeRoutine.phase != .outside || chiikawaWakingAt != nil { wakeChiikawa() }
        state.showFriends = true; state.roaming = true
        state.visibleFriends.insert(.chiikawa); state.walkingFriends.insert(.chiikawa)
        chiikawaActor?.dismissBubble(); chiikawaActor?.motion.retarget()
        chiikawaWorld.requested = item; chiikawaItemTarget = nil
        state.chiikawaItemStatus = "\(item.name) 주우러 가는 중"
    }
    func dropChiikawaItem(now: Date = Date()) {
        guard let actor = chiikawaActor, let bounds = actor.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        stopChiikawaLife()
        let point = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
        chiikawaWorld.drop(at: NSPoint(x: point.x + 88, y: point.y), bounds: bounds, now: now)
        chiikawaWorld.requested = nil; chiikawaItemTarget = nil; actor.motion.retarget()
        publishChiikawaEquipment(); state.chiikawaItemStatus = "소품을 내려놓았어요"
    }
    @discardableResult
    func receiveChiikawaItem(_ item: ChiikawaItem, at point: NSPoint, now: Date = Date()) -> Bool {
        guard state.isVisible(.chiikawa), state.chiikawaItems.contains(item),
              let actor = chiikawaActor, actor.panel.isVisible, !actor.view.isDragging,
              !chiikawaHomeRoutine.isInside,
              chiikawaDesktopItems[item]?.view.isDragging == false,
              DesktopGeometry.hit(point, in: actor.panel.frame),
              let bounds = actor.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame,
              chiikawaWorld.equip(item, at: actor.panel.frame.origin, bounds: bounds, now: now) else { return false }
        stopChiikawaLife()
        if chiikawaHomeRoutine.phase == .returning {
            if item == .houseKey { chiikawaSeekingHomeKey = false }
            else { wakeChiikawa(now: now) }
        }
        chiikawaItemTarget = nil; actor.motion.retarget(); actor.view.chiikawaItem = item
        actor.view.needsDisplay = true; chiikawaDesktopItems[item]?.panel.orderOut(nil)
        publishChiikawaEquipment(); state.chiikawaItemStatus = "\(item.name)를 건네받았어요"
        if item == .stuffedToy { playChiikawaLife(.hug, now: now) }
        return true
    }
    func publishChiikawaEquipment() {
        if state.chiikawaEquipped != chiikawaWorld.equipped { state.chiikawaEquipped = chiikawaWorld.equipped }
    }
    private func pickUpChiikawaItem(_ item: ChiikawaItem, actor: FriendActor, bounds: NSRect, now: Date) -> Bool {
        guard chiikawaWorld.pickUp(item, from: actor.panel.frame.origin, bounds: bounds, now: now) else { return false }
        actor.motion.retarget(); chiikawaItemTarget = nil
        publishChiikawaEquipment(); state.chiikawaItemStatus = "\(item.name)를 주웠어요"
        if item == .stuffedToy && chiikawaHomeRoutine.phase == .outside { playChiikawaLife(.hug, now: now) }
        if item == .houseKey && chiikawaSeekingHomeKey { chiikawaSeekingHomeKey = false }
        return true
    }

    /// Chiikawa shares world geometry and gait mechanics, while its inventory,
    /// routes, bubbles and reactions never touch Hachiware's daily/home/voice state.
    func tickChiikawa(_ actor: FriendActor, now: Date, dt: TimeInterval, time: Double,
                     mouse: NSPoint, pointerCanReachCharacter: Bool?) {
        if let bounds = NSScreen.main?.visibleFrame {
            let previous = chiikawaWorld.equipped
            chiikawaWorld.configure(enabled: state.chiikawaItems, bounds: bounds)
            if previous == .stuffedToy && chiikawaWorld.equipped != previous && chiikawaLifeRoutine.selected == .hug { stopChiikawaLife() }
            configureChiikawaStudy(in: bounds)
        }
        if chiikawaSeekingHomeKey && chiikawaWorld.ground[.houseKey] == nil { chiikawaSeekingHomeKey = false }
        publishChiikawaEquipment()
        let visible = state.isVisible(.chiikawa)
        guard visible else {
            stopChiikawaLife(); stopChiikawaVoice()
            if chiikawaHomeRoutine.phase != .outside || chiikawaWakingAt != nil { wakeChiikawa(now: now) }
            actor.panel.orderOut(nil); actor.dismissBubble(); actor.motion.stop(); actor.wasHovered = false
            actor.view.action = nil; actor.view.actionTime = nil; actor.view.chiikawaLife = nil
            updateChiikawaLifeObjects(visible: false, mouse: mouse, actor: actor, now: now, time: time)
            return
        }
        chiikawaHomeRoutine.advance(now: now)
        if chiikawaHomeRoutine.shouldWake(now: now) { wakeChiikawa(now: now, animated: true) }
        if chiikawaLifeRoutine.selected != nil && chiikawaLifeRoutine.action(now: now) == nil { stopChiikawaLife() }
        if let waking = chiikawaWakingAt, now.timeIntervalSince(waking) >= ChiikawaMotionSprites.wakeDuration { wakeChiikawa(now: now) }
        if !chiikawaHomeRoutine.isInside && chiikawaWakingAt == nil { _ = enterChiikawaHomeIfReached(actor, now: now) }
        if chiikawaHomeRoutine.isInside || chiikawaWakingAt != nil {
            actor.panel.orderOut(nil); actor.motion.stop()
            publishChiikawaHome()
            updateChiikawaLifeObjects(visible: visible, mouse: mouse, actor: actor, now: now, time: time)
            return
        }
        if !actor.panel.isVisible { actor.panel.orderFrontRegardless() }
        let hovered = actor.pointerIsHovering(at: mouse,
            armed: state.expressive && chiikawaWorld.equipped == .pinkSasumata, canReach: pointerCanReachCharacter)
        actor.panel.ignoresMouseEvents = !hovered && !actor.view.isDragging
        let activity = DesktopActivity.resolve(roaming: state.isWalking(.chiikawa), hovered: hovered,
            dragging: actor.view.isDragging, dialogueUntil: actor.bubbleUntil, now: now)
        let armedHover = state.expressive && activity == .hovering && chiikawaWorld.equipped == .pinkSasumata
        if armedHover && chiikawaLifeRoutine.selected != nil { stopChiikawaLife() }
        if hovered && !actor.wasHovered { actor.hoverStarted = now }
        actor.wasHovered = hovered
        chiikawaStudyWorld.observe(contact: ItemWorld.contactPoint(origin: actor.panel.frame.origin))
        if activity == .walking || activity == .idle { _ = triggerChiikawaStudy(actor, now: now) }
        if activity == .walking, chiikawaLifeRoutine.action(now: now) == nil,
           chiikawaStudyWorld.requested == nil, chiikawaWorld.requested == nil,
           chiikawaHomeRoutine.shouldReturn(now: now, automatic: state.chiikawaAutomaticRest, roaming: state.isWalking(.chiikawa)) {
            goChiikawaHome(now: now)
        }
        if activity == .walking, chiikawaLifeRoutine.action(now: now) == nil, let screen = actor.panel.screen ?? NSScreen.main {
            let frame = actor.panel.frame
            let dragged = Set(chiikawaDesktopItems.filter { $0.value.view.isDragging }.map(\.key))
            let followingHome = chiikawaHomeRoutine.phase == .returning
            let followingStudy = chiikawaStudyWorld.requested != nil
            let suppressAutomatic = followingHome || followingStudy
            let nearby = suppressAutomatic ? nil : chiikawaWorld.nearbyTarget(from: frame.origin, automatic: state.chiikawaAutomaticItems, now: now, excluding: dragged)
            let target = followingHome ? (chiikawaSeekingHomeKey ? ChiikawaItem.houseKey : nil)
                : followingStudy ? nil : nearby ?? chiikawaWorld.target(from: frame.origin, automatic: state.chiikawaAutomaticItems, now: now, excluding: dragged)
            if chiikawaItemTarget != target { actor.motion.retarget(); chiikawaItemTarget = target }
            if let target, let point = chiikawaWorld.ground[target] {
                actor.motion.destination = ItemWorld.destination(for: point)
                if !dragged.contains(target) { _ = pickUpChiikawaItem(target, actor: actor, bounds: screen.visibleFrame, now: now) }
            }
            if followingHome && !chiikawaSeekingHomeKey {
                actor.motion.destination = ItemWorld.destination(for: home.entrance)
            } else if followingStudy, let spot = chiikawaStudyWorld.requested, let point = chiikawaStudyWorld.positions[spot] {
                actor.motion.destination = ItemWorld.destination(for: point)
            }
            if actor.motion.destination == nil {
                var target = frame.origin
                for _ in 0..<8 {
                    target = RoamingMotion.target(in: screen.visibleFrame, size: frame.size,
                        xFraction: .random(in: 0.03...0.97), yFraction: .random(in: 0.03...0.97))
                    if hypot(target.x - frame.minX, target.y - frame.minY) > min(screen.visibleFrame.width, screen.visibleFrame.height) * 0.28 { break }
                }
                actor.motion.destination = target
            }
            if chiikawaLifeRoutine.action(now: now) == nil {
                let bounds = followingHome ? screen.visibleFrame.union(home.panel.screen?.visibleFrame ?? screen.visibleFrame) : screen.visibleFrame
                actor.panel.setFrameOrigin(actor.motion.advance(from: frame.origin, dt: dt, bounds: bounds, size: frame.size,
                    stoppingDistance: chiikawaStudyWorld.requested == nil ? 5 : ActivitySpotWorld.stoppingDistance))
            } else { actor.motion.stop() }
            actor.gait.recordMovement(from: frame.origin, to: actor.panel.frame.origin)
            _ = enterChiikawaHomeIfReached(actor, now: now)
            if !chiikawaHomeRoutine.isInside { _ = triggerChiikawaStudy(actor, now: now) }
            if !suppressAutomatic && chiikawaLifeRoutine.action(now: now) == nil && !chiikawaHomeRoutine.isInside,
               let nearby = chiikawaWorld.nearbyTarget(from: actor.panel.frame.origin,
                automatic: state.chiikawaAutomaticItems, now: now, excluding: dragged) {
                _ = pickUpChiikawaItem(nearby, actor: actor, bounds: screen.visibleFrame, now: now)
            }
        } else { actor.motion.stop() }
        actor.view.time = time + actor.phase; actor.view.walking = actor.motion.isWalking
        actor.view.facing = actor.motion.facing; actor.view.walkPhase = actor.gait.phase
        actor.view.pose = HachiwarePose.forVelocity(actor.motion.velocity)
        let lifeAction = chiikawaLifeRoutine.action(now: now)
        let attacking = armedHover && lifeAction == nil
        if attacking && actor.view.action != .attack { actor.hoverStarted = now }
        actor.view.happy = state.expressive && activity.reacts && !attacking
        actor.view.chiikawaLife = lifeAction
        actor.view.chiikawaReaction = state.expressive && !attacking
            ? (activity == .hovering ? .happy : activity == .speaking ? actor.clickReaction : nil) : nil
        actor.view.action = attacking ? .attack : nil
        actor.view.actionTime = lifeAction != nil ? chiikawaLifeRoutine.elapsed(now: now)
            : attacking ? max(0, now.timeIntervalSince(actor.hoverStarted)) : nil
        if attacking {
            actor.view.previousChiikawaReaction = nil
            actor.view.chiikawaReactionChanged = -Double.infinity
        }
        actor.view.chiikawaItem = chiikawaWorld.equipped; actor.view.invalidateCurrentDrawing()
        if now < actor.bubbleUntil { actor.positionBubble() } else if actor.bubble != nil { actor.dismissBubble() }
        publishChiikawaHome()
        updateChiikawaLifeObjects(visible: visible, mouse: mouse, actor: actor, now: now, time: time)
    }
}
