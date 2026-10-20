import AppKit

extension DesktopController {
    func callFriend(_ friend: Friend) {
        guard let actor = actors.first(where: { $0.friend == friend }),
              let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        if friend == .hachiware {
            stopDailyAction(); stopCharacterVoice()
            if homeRoutine.phase != .outside { wakeFromHome() }
            itemTarget = nil
        } else { chiikawaItemTarget = nil }
        state.showFriends = true; state.visibleFriends.insert(friend)
        actor.dismissBubble(); actor.motion.retarget()
        let index = Friend.developmentRoster.firstIndex(of: friend) ?? 0
        actor.panel.setFrameOrigin(RoamingMotion.target(in: screen.visibleFrame, size: actor.panel.frame.size,
            xFraction: 0.18 + CGFloat(index) * 0.16, yFraction: 0.28))
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
        state.showFriends = true; state.roaming = true
        state.visibleFriends.insert(.chiikawa); state.walkingFriends.insert(.chiikawa)
        chiikawaActor?.dismissBubble(); chiikawaActor?.motion.retarget()
        chiikawaWorld.requested = item; chiikawaItemTarget = nil
        state.chiikawaItemStatus = "\(item.name) 주우러 가는 중"
    }
    func dropChiikawaItem(now: Date = Date()) {
        guard let actor = chiikawaActor, let bounds = actor.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let point = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
        chiikawaWorld.drop(at: NSPoint(x: point.x + 88, y: point.y), bounds: bounds, now: now)
        chiikawaWorld.requested = nil; chiikawaItemTarget = nil; actor.motion.retarget()
        publishChiikawaEquipment(); state.chiikawaItemStatus = "소품을 내려놓았어요"
    }
    @discardableResult
    func receiveChiikawaItem(_ item: ChiikawaItem, at point: NSPoint, now: Date = Date()) -> Bool {
        guard state.isVisible(.chiikawa), state.chiikawaItems.contains(item),
              let actor = chiikawaActor, actor.panel.isVisible, !actor.view.isDragging,
              chiikawaDesktopItems[item]?.view.isDragging == false,
              DesktopGeometry.hit(point, in: actor.panel.frame),
              let bounds = actor.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame,
              chiikawaWorld.equip(item, at: actor.panel.frame.origin, bounds: bounds, now: now) else { return false }
        chiikawaItemTarget = nil; actor.motion.retarget(); actor.view.chiikawaItem = item
        actor.view.needsDisplay = true; chiikawaDesktopItems[item]?.panel.orderOut(nil)
        publishChiikawaEquipment(); state.chiikawaItemStatus = "\(item.name)를 건네받았어요"
        return true
    }
    private func publishChiikawaEquipment() {
        if state.chiikawaEquipped != chiikawaWorld.equipped { state.chiikawaEquipped = chiikawaWorld.equipped }
    }
    private func pickUpChiikawaItem(_ item: ChiikawaItem, actor: FriendActor, bounds: NSRect, now: Date) -> Bool {
        guard chiikawaWorld.pickUp(item, from: actor.panel.frame.origin, bounds: bounds, now: now) else { return false }
        actor.motion.retarget(); chiikawaItemTarget = nil
        publishChiikawaEquipment(); state.chiikawaItemStatus = "\(item.name)를 주웠어요"
        return true
    }

    /// Chiikawa shares world geometry and gait mechanics, while its inventory,
    /// routes, bubbles and reactions never touch Hachiware's daily/home/voice state.
    func tickChiikawa(_ actor: FriendActor, now: Date, dt: TimeInterval, time: Double,
                     mouse: NSPoint, pointerCanReachCharacter: Bool?) {
        if let bounds = NSScreen.main?.visibleFrame { chiikawaWorld.configure(enabled: state.chiikawaItems, bounds: bounds) }
        publishChiikawaEquipment()
        let visible = state.isVisible(.chiikawa)
        guard visible else {
            actor.panel.orderOut(nil); actor.dismissBubble(); actor.motion.stop(); actor.wasHovered = false
            for object in chiikawaDesktopItems.values { object.update(position: nil, visible: false, mouse: mouse) }
            return
        }
        if !actor.panel.isVisible { actor.panel.orderFrontRegardless() }
        let hovered = !actor.view.isDragging && (pointerCanReachCharacter ?? actor.panel.occlusionState.contains(.visible))
            && DesktopGeometry.hit(mouse, in: actor.panel.frame)
        actor.panel.ignoresMouseEvents = !hovered && !actor.view.isDragging
        let activity = DesktopActivity.resolve(roaming: state.isWalking(.chiikawa), hovered: hovered,
            dragging: actor.view.isDragging, dialogueUntil: actor.bubbleUntil, now: now)
        actor.wasHovered = hovered
        if activity == .walking, let screen = actor.panel.screen ?? NSScreen.main {
            let frame = actor.panel.frame
            let dragged = Set(chiikawaDesktopItems.filter { $0.value.view.isDragging }.map(\.key))
            let nearby = chiikawaWorld.nearbyTarget(from: frame.origin, automatic: state.chiikawaAutomaticItems, now: now, excluding: dragged)
            let target = nearby ?? chiikawaWorld.target(from: frame.origin, automatic: state.chiikawaAutomaticItems, now: now, excluding: dragged)
            if chiikawaItemTarget != target { actor.motion.retarget(); chiikawaItemTarget = target }
            if let target, let point = chiikawaWorld.ground[target] {
                actor.motion.destination = ItemWorld.destination(for: point)
                _ = pickUpChiikawaItem(target, actor: actor, bounds: screen.visibleFrame, now: now)
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
            actor.panel.setFrameOrigin(actor.motion.advance(from: frame.origin, dt: dt, bounds: screen.visibleFrame, size: frame.size))
            actor.gait.recordMovement(from: frame.origin, to: actor.panel.frame.origin)
            if let nearby = chiikawaWorld.nearbyTarget(from: actor.panel.frame.origin,
                automatic: state.chiikawaAutomaticItems, now: now, excluding: dragged) {
                _ = pickUpChiikawaItem(nearby, actor: actor, bounds: screen.visibleFrame, now: now)
            }
        } else { actor.motion.stop() }
        actor.view.time = time + actor.phase; actor.view.walking = actor.motion.isWalking
        actor.view.facing = actor.motion.facing; actor.view.walkPhase = actor.gait.phase
        actor.view.pose = HachiwarePose.forVelocity(actor.motion.velocity)
        actor.view.happy = state.expressive && activity.reacts
        actor.view.chiikawaReaction = state.expressive
            ? (activity == .hovering ? .happy : activity == .speaking ? actor.clickReaction : nil) : nil
        actor.view.chiikawaItem = chiikawaWorld.equipped; actor.view.needsDisplay = true
        if now < actor.bubbleUntil { actor.positionBubble() } else if actor.bubble != nil { actor.dismissBubble() }
        for (item, object) in chiikawaDesktopItems { object.update(position: chiikawaWorld.ground[item], visible: visible, mouse: mouse) }
    }
}
