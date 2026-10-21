import AppKit

extension DesktopController {
    func configureChiikawaLife() {
        _ = ChiikawaLifeSprites.shared
        chiikawaDesk.view.onSeek = { [weak self] in self?.seekChiikawaStudy() }
        chiikawaDesk.view.onMove = { [weak self] point in
            guard let self, let bounds = (NSScreen.screens.first { $0.frame.contains(point) } ?? self.chiikawaDesk.panel.screen ?? NSScreen.main)?.visibleFrame else { return }
            if self.chiikawaLifeRoutine.selected == .study { self.stopChiikawaLife() }
            self.chiikawaStudyWorld.move(.desk, to: point, bounds: bounds)
            if self.chiikawaStudyWorld.requested != nil { self.chiikawaActor?.motion.retarget() }
        }
        chiikawaDesk.view.onMoveEnd = { [weak self] in
            guard let self, let actor = self.chiikawaActor else { return }
            _ = self.triggerChiikawaStudy(actor, now: Date())
        }
        chiikawaVoice.onStatus = { [weak state] status in state?.chiikawaVoiceStatus = status }
        state.onChiikawaGoHome = { [weak self] in self?.goChiikawaHome() }
        state.onChiikawaWake = { [weak self] in self?.wakeChiikawa() }
        state.onChiikawaStudy = { [weak self] in self?.seekChiikawaStudy() }
        state.onChiikawaLife = { [weak self] action in self?.playChiikawaLife(action) }
        state.onStopChiikawaLife = { [weak self] in self?.stopChiikawaLife() }
        state.onChiikawaVoicePreview = { [weak self] in self?.sayChiikawa(preview: true) }
        state.onStopChiikawaVoice = { [weak self] in self?.stopChiikawaVoice() }
    }

    func configureChiikawaStudy(in bounds: NSRect) {
        let wasEnabled = chiikawaStudyWorld.enabled.contains(.desk)
        chiikawaStudyWorld.configure(enabled: state.chiikawaStudyEnabled ? [.desk] : [], bounds: bounds)
        if !wasEnabled && state.chiikawaStudyEnabled {
            let point = ItemWorld.contactPoint(origin: RoamingMotion.target(in: bounds, size: NSSize(width: 132,height: 150), xFraction: 0.80,yFraction: 0.64))
            chiikawaStudyWorld.move(.desk, to: point, bounds: bounds)
        }
        if !state.chiikawaStudyEnabled && chiikawaLifeRoutine.selected == .study { stopChiikawaLife() }
    }

    func seekChiikawaStudy(now: Date = Date()) {
        state.chiikawaStudyEnabled = true
        if let bounds = NSScreen.main?.visibleFrame { configureChiikawaStudy(in: bounds) }
        guard chiikawaStudyWorld.positions[.desk] != nil else { return }
        stopChiikawaLife(); stopChiikawaVoice()
        if chiikawaHomeRoutine.phase != .outside { wakeChiikawa(now: now) }
        state.showFriends = true; state.roaming = true
        state.visibleFriends.insert(.chiikawa); state.walkingFriends.insert(.chiikawa)
        chiikawaActor?.dismissBubble(); chiikawaActor?.motion.retarget()
        chiikawaWorld.requested = nil; chiikawaItemTarget = nil
        chiikawaStudyWorld.requested = .desk
        state.chiikawaLifeRunning = true; state.chiikawaLifeStatus = "분홍 책상으로 걸어가는 중"
    }

    @discardableResult
    func triggerChiikawaStudy(_ actor: FriendActor, now: Date) -> Bool {
        guard actor.friend == .chiikawa, !actor.view.isDragging, now >= actor.bubbleUntil,
              chiikawaLifeRoutine.action(now: now) == nil, chiikawaHomeRoutine.phase == .outside,
              chiikawaWorld.requested == nil, !chiikawaDesk.view.isDragging else { return false }
        let contact = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
        chiikawaStudyWorld.observe(contact: contact)
        guard chiikawaStudyWorld.encounter(contact: contact, automatic: state.chiikawaAutomaticActivities, now: now) == .desk else { return false }
        playChiikawaLife(.study, atDesk: true, now: now)
        return true
    }

    func playChiikawaLife(_ action: ChiikawaLifeAction, atDesk: Bool = false, now: Date = Date()) {
        guard let actor = chiikawaActor else { return }
        if chiikawaHomeRoutine.phase != .outside { wakeChiikawa(now: now) }
        stopChiikawaVoice(); actor.dismissBubble(); actor.motion.retarget()
        chiikawaWorld.requested = nil; chiikawaItemTarget = nil; chiikawaSeekingHomeKey = false
        chiikawaStudyWorld.requested = nil
        if atDesk, action == .study, let point = chiikawaStudyWorld.positions[.desk] {
            actor.panel.setFrameOrigin(ItemWorld.destination(for: point)); chiikawaStudyWorld.consume(.desk, now: now)
        }
        chiikawaStudyingAtDesk = atDesk && action == .study
        chiikawaLifeRoutine.begin(action, now: now)
        state.showFriends = true; state.visibleFriends.insert(.chiikawa)
        actor.view.chiikawaLife = action; actor.view.actionTime = 0; actor.view.walking = false
        actor.view.needsDisplay = true; actor.panel.orderFrontRegardless()
        state.chiikawaLifeRunning = true; state.chiikawaLifeStatus = "\(action.title) · 끝나면 다시 산책해요"
    }

    func stopChiikawaLife() {
        chiikawaLifeRoutine.cancel(); chiikawaStudyingAtDesk = false
        if chiikawaStudyWorld.requested != nil { chiikawaStudyWorld.requested = nil; chiikawaActor?.motion.retarget() }
        if chiikawaActor?.view.chiikawaLife != nil {
            chiikawaActor?.view.chiikawaLife = nil; chiikawaActor?.view.actionTime = nil
            chiikawaActor?.motion.retarget(); chiikawaActor?.view.needsDisplay = true
        }
        if state.chiikawaLifeRunning { state.chiikawaLifeRunning = false }
        let status = "공부하고, 인형을 안고, 잠옷으로 쉬어요"
        if state.chiikawaLifeStatus != status { state.chiikawaLifeStatus = status }
    }

    func goChiikawaHome(now: Date = Date()) {
        guard !chiikawaHomeRoutine.isInside else { return }
        stopChiikawaLife(); stopChiikawaVoice()
        state.showFriends = true; state.roaming = true
        state.visibleFriends.insert(.chiikawa); state.walkingFriends.insert(.chiikawa)
        chiikawaActor?.dismissBubble(); chiikawaActor?.motion.retarget()
        chiikawaHomeRoutine.request(now: now)
        chiikawaSeekingHomeKey = chiikawaWorld.ground[.houseKey] != nil
        chiikawaWorld.requested = chiikawaSeekingHomeKey ? .houseKey : nil
        chiikawaItemTarget = nil; publishChiikawaHome()
    }

    func wakeChiikawa(now: Date = Date()) {
        let wasInside = chiikawaHomeRoutine.isInside
        chiikawaHomeRoutine.wake(now: now)
        if chiikawaSeekingHomeKey { chiikawaWorld.requested = nil }
        chiikawaSeekingHomeKey = false; chiikawaItemTarget = nil
        if let actor = chiikawaActor {
            if wasInside {
                let bounds = home.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? home.panel.frame
                actor.panel.setFrameOrigin(DesktopGeometry.clamp(ItemWorld.destination(for: home.entrance), size: actor.panel.frame.size, to: bounds))
            }
            actor.motion.retarget()
            if state.isWalking(.chiikawa) && wasInside {
                actor.motion.destination = NSPoint(x: actor.panel.frame.minX-150,y: actor.panel.frame.minY+90)
            }
        }
        publishChiikawaHome()
    }

    @discardableResult
    func enterChiikawaHomeIfReached(_ actor: FriendActor, now: Date) -> Bool {
        guard actor.friend == .chiikawa, !actor.view.isDragging,
              now >= actor.bubbleUntil, chiikawaLifeRoutine.action(now: now) == nil,
              chiikawaStudyWorld.requested == nil, !chiikawaSeekingHomeKey,
              chiikawaHomeRoutine.arrive(contact: ItemWorld.contactPoint(origin: actor.panel.frame.origin), entrance: home.entrance, now: now) else { return false }
        let bounds = home.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? home.panel.frame
        chiikawaWorld.drop(at: NSPoint(x: home.panel.frame.maxX-20,y: home.entrance.y), bounds: bounds, now: now)
        chiikawaWorld.requested = nil; chiikawaItemTarget = nil
        stopChiikawaLife(); stopChiikawaVoice(); actor.dismissBubble(); actor.motion.retarget(); actor.panel.orderOut(nil)
        publishChiikawaEquipment(); publishChiikawaHome()
        return true
    }

    func publishChiikawaHome() {
        let status = chiikawaSeekingHomeKey ? "집 열쇠를 챙기러 가는 중" : chiikawaHomeRoutine.phase == .outside
            ? "공용 집에서 함께 쉴 수 있어요" : chiikawaHomeRoutine.status
        if state.chiikawaHomeStatus != status { state.chiikawaHomeStatus = status }
        if state.chiikawaResting != chiikawaHomeRoutine.isInside { state.chiikawaResting = chiikawaHomeRoutine.isInside }
    }

    func didMoveChiikawa(_ actor: FriendActor, now: Date = Date()) {
        chiikawaItemTarget = nil; actor.motion.retarget()
        if triggerChiikawaStudy(actor, now: now) { return }
        guard hypot(ItemWorld.contactPoint(origin: actor.panel.frame.origin).x-home.entrance.x,
                    ItemWorld.contactPoint(origin: actor.panel.frame.origin).y-home.entrance.y) <= 24 else { return }
        chiikawaHomeRoutine.request(now: now); chiikawaSeekingHomeKey = false; chiikawaWorld.requested = nil
        _ = enterChiikawaHomeIfReached(actor, now: now)
    }

    func sayChiikawa(preview: Bool = false, now: Date = Date()) {
        guard let actor = chiikawaActor else { return }
        stopChiikawaLife()
        if chiikawaHomeRoutine.phase != .outside { wakeChiikawa(now: now) }
        if let line = RecordingCatalog.chiikawa.choose(excluding: lastChiikawaVoiceID) {
            lastChiikawaVoiceID = line.id; actor.lastGreeting = line.id
            actor.clickReaction = Self.chiikawaReaction(for: line.id)
            if state.isVisible(.chiikawa) { actor.say(line.text, now: now, duration: max(2,line.duration+0.35)) }
            if preview || state.chiikawaVoice {
                chiikawaVoice.play(line, volume: state.characterVolume)
            } else { state.chiikawaVoiceStatus = "치이카와 클릭 목소리를 꺼 두었어요" }
        } else {
            let choices = ChiikawaReaction.greetings.filter { $0.0 != actor.lastGreeting }
            guard let selected = choices.randomElement() else { return }
            actor.lastGreeting = selected.0; actor.clickReaction = selected.1; actor.say(selected.0, now: now)
            state.chiikawaVoiceStatus = "한국어 녹음 파일을 준비하지 못했어요"
        }
    }

    static func chiikawaReaction(for recordingID: String) -> ChiikawaReaction {
        if recordingID.contains("cry") { return .crying }
        if recordingID.contains("surprise") { return .startled }
        if recordingID.contains("effort") { return .determined }
        return .gentle
    }
    func stopChiikawaVoice() {
        guard chiikawaVoice.player != nil else { return }
        chiikawaVoice.stop(); state.chiikawaVoiceStatus = "목소리 재생을 멈췄어요"
    }
    func updateChiikawaLifeObjects(visible: Bool, mouse: NSPoint, actor: FriendActor, now: Date, time: Double) {
        chiikawaDesk.update(position: chiikawaStudyWorld.positions[.desk],
            visible: visible && !(chiikawaStudyingAtDesk && chiikawaLifeRoutine.selected == .study), mouse: mouse,
            behind: actor.panel.isVisible ? actor.panel.windowNumber : nil)
        for (item,object) in chiikawaDesktopItems { object.update(position: chiikawaWorld.ground[item], visible: visible, mouse: mouse) }
    }
}
