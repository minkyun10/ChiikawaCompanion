import AppKit
import AVFoundation

final class FriendPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

enum DesktopGeometry {
    static func clamp(_ origin: NSPoint, size: NSSize, to visible: NSRect) -> NSPoint {
        NSPoint(x: min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - size.width)),
                y: min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - size.height)))
    }
    static func hit(_ point: NSPoint, in rect: NSRect) -> Bool {
        // Leave the transparent corners and space above the character click-through.
        rect.insetBy(dx: rect.width * 0.13, dy: rect.height * 0.06).contains(point)
    }
}

final class DesktopFriendView: NSView {
    let friend: Friend
    var happy = false
    var walking = false
    var time = 0.0
    var looking: CGFloat = 0
    var facing: CGFloat = 1
    var walkPhase = 0.0
    var pose = HachiwarePose.front
    var action: HachiwareAction?
    var actionTime: Double?
    var equipped: CompanionItem?
    var isDragging = false
    var onClick: (() -> Void)?
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onDailyAction: ((HachiwareAction) -> Void)?
    var onStopDailyAction: (() -> Void)?
    private var downPoint: NSPoint = .zero
    private var downOrigin: NSPoint = .zero
    private var moved = false

    init(friend: Friend) {
        self.friend = friend
        super.init(frame: NSRect(x: 0, y: 0, width: 132, height: 150))
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("\(friend.name) — 클릭해 인사하기, 드래그로 이동, 우클릭해 일상 동작 고르기.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onClick?(); return true }
    override func draw(_ dirtyRect: NSRect) {
        FriendArtwork.draw(friend, in: bounds, time: time, happy: happy, walking: walking,
                           looking: looking, facing: facing, walkPhase: walkPhase, pose: pose,
                           action: action, equipped: equipped, actionTime: actionTime)
    }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        for action in HachiwareAction.daily {
            let entry = NSMenuItem(title: action.title, action: #selector(chooseDailyAction(_:)), keyEquivalent: "")
            entry.target = self; entry.tag = action.rawValue; menu.addItem(entry)
        }
        menu.addItem(.separator())
        let stop = NSMenuItem(title: "동작 멈추기", action: #selector(stopDailyAction), keyEquivalent: "")
        stop.target = self; menu.addItem(stop)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    @objc private func chooseDailyAction(_ sender: NSMenuItem) {
        guard let action = HachiwareAction(rawValue: sender.tag), action.isDaily else { return }
        onDailyAction?(action)
    }
    @objc private func stopDailyAction() { onStopDailyAction?() }
    override func mouseDown(with event: NSEvent) {
        onDragStart?()
        isDragging = true; moved = false
        downPoint = NSEvent.mouseLocation
        downOrigin = window?.frame.origin ?? .zero
    }
    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - downPoint.x, dy = mouse.y - downPoint.y
        if abs(dx) + abs(dy) > 4 { moved = true }
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let origin = NSPoint(x: downOrigin.x + dx, y: downOrigin.y + dy)
        window.setFrameOrigin(DesktopGeometry.clamp(origin, size: window.frame.size,
                                                    to: screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)))
    }
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if moved { onDragEnd?() } else { onClick?() }
    }
}

final class FriendActor {
    let friend: Friend
    let panel: FriendPanel
    let view: DesktopFriendView
    var motion = RoamingMotion()
    var gait = WalkingGait()
    let phase: Double
    var bubble: NSPanel?
    var bubbleUntil = Date.distantPast
    var performance = CompanionPerformance()
    var dailyPerformance = DailyActionPerformance()
    var hoverStarted = Date.distantPast
    var wasHovered = false

    init(friend: Friend, index: Int) {
        self.friend = friend
        phase = Double(index) * 1.7
        view = DesktopFriendView(friend: friend)
        panel = FriendPanel(contentRect: view.bounds, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = view
        panel.title = "친구 · \(friend.name)"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.isFloatingPanel = false
        panel.level = DesktopLayer.character
        panel.collectionBehavior = DesktopLayer.collection
        panel.animationBehavior = .none
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.setAccessibilityLabel(friend.name)
    }
    func say(_ text: String, now: Date, duration: TimeInterval = 4, heading: String? = nil) {
        dismissBubble()
        let textWidth: CGFloat = 288
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let measured = (text as NSString).boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font]).height
        let textHeight = min(156, max(34, ceil(measured) + 4))
        let height = textHeight + 44
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: height),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
        p.title = "\(friend.name) 알림"
        p.isReleasedWhenClosed = false
        p.isFloatingPanel = false
        p.level = DesktopLayer.bubble; p.hidesOnDeactivate = false; p.ignoresMouseEvents = true
        p.collectionBehavior = DesktopLayer.collection
        let container = NSView(frame: p.contentView!.bounds)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(hex: 0xFFFDF6).cgColor
        container.layer?.cornerRadius = 19
        container.layer?.borderWidth = 1.5
        container.layer?.borderColor = friend.color.withAlphaComponent(0.65).cgColor
        let title = NSTextField(labelWithString: heading.map { "\(friend.name) · \($0)" } ?? friend.name)
        title.font = .systemFont(ofSize: 10, weight: .semibold)
        title.textColor = NSColor(hex: 0xA08C7D)
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 16, y: height - 24, width: textWidth, height: 14)
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = FriendArtwork.ink
        label.maximumNumberOfLines = 8
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 16, y: 12, width: textWidth, height: textHeight)
        label.setAccessibilityLabel(text)
        container.addSubview(title); container.addSubview(label)
        p.contentView = container
        bubble = p; bubbleUntil = now.addingTimeInterval(duration)
        positionBubble()
        p.orderFrontRegardless()
    }
    func dismissBubble() {
        for case let field as NSTextField in bubble?.contentView?.subviews ?? [] {
            field.stringValue = ""
            field.setAccessibilityLabel("")
        }
        bubble?.close()
        bubble = nil
        bubbleUntil = .distantPast
    }
    func positionBubble() {
        guard let bubble else { return }
        let screen = panel.screen ?? NSScreen.main
        let desired = NSPoint(x: panel.frame.midX - bubble.frame.width / 2, y: panel.frame.maxY + 5)
        bubble.setFrameOrigin(DesktopGeometry.clamp(desired, size: bubble.frame.size,
                                                   to: screen?.visibleFrame ?? panel.frame))
    }
}

final class DesktopController {
    let state: AppState
    var actors: [FriendActor] = []
    var timer: Timer?
    let speech = AVSpeechSynthesizer()
    let recordedVoice: RecordedVoicePlayer
    var lastRecordedLine: String?
    var lastClickDialogueID: String?
    let started = Date()
    var lastTick = Date()
    var screenObserver: NSObjectProtocol?
    var itemWorld = ItemWorld()
    var desktopItems: [CompanionItem: DesktopItem] = [:]
    var itemTarget: CompanionItem?
    var activityWorld = ActivitySpotWorld()
    var desktopActivitySpots: [ActivitySpot: DesktopActivitySpot] = [:]
    private(set) var activeActivitySpot: ActivitySpot?
    let home = DesktopHome()
    var homeRoutine = HomeRoutine()

    init(state: AppState, startTimer: Bool = true, recordedVoice: RecordedVoicePlayer = RecordedVoicePlayer()) {
        self.state = state
        self.recordedVoice = recordedVoice
        // Decode and register once at launch, never on the first pointer hover.
        _ = HachiwareSprites.shared
        _ = HachiwareActions.shared
        actors = Friend.developmentRoster.enumerated().map { FriendActor(friend: $0.element, index: $0.offset) }
        for actor in actors {
            actor.view.onClick = { [weak self, weak actor] in
                guard let self, let actor else { return }
                self.handleCharacterClick(actor)
            }
            actor.view.onDragStart = { [weak self] in
                self?.stopCharacterVoice()
                self?.stopDailyAction()
                guard let self, self.homeRoutine.phase == .returning else { return }
                self.wakeFromHome()
            }
            actor.view.onDailyAction = { [weak self] action in self?.playDailyAction(action) }
            actor.view.onStopDailyAction = { [weak self] in self?.stopDailyAction() }
            actor.view.onDragEnd = { [weak self, weak actor] in
                actor?.motion.retarget()
                // Ground props own screen coordinates. Moving the character only
                // invalidates its route; it must never reposition those props.
                self?.itemTarget = nil
                if let self, let actor, self.triggerNearbyActivity(actor, now: Date()) { return }
                if let self, let actor, self.state.homeEnabled {
                    let contact = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
                    if hypot(contact.x - self.home.entrance.x, contact.y - self.home.entrance.y) <= 24 {
                        // A deliberate drop at the doorway overrides the automatic-entry cooldown.
                        let now = Date()
                        self.homeRoutine.request(now: now)
                        _ = self.enterHomeIfReached(actor, now: now)
                    }
                }
            }
        }
        for item in CompanionItem.allCases {
            let desktopItem = DesktopItem(item: item)
            desktopItem.view.onSeek = { [weak self] in self?.seekItem(item) }
            desktopItem.view.onMove = { [weak self, weak desktopItem] point in
                guard let self, let bounds = (NSScreen.screens.first { $0.frame.contains(point) }
                    ?? desktopItem?.panel.screen ?? NSScreen.main)?.visibleFrame else { return }
                self.itemWorld.move(item, to: point, bounds: bounds)
            }
            desktopItems[item] = desktopItem
        }
        for spot in ActivitySpot.allCases {
            let object = DesktopActivitySpot(spot: spot)
            object.view.onSeek = { [weak self] in self?.seekActivitySpot(spot) }
            object.view.onMove = { [weak self, weak object] point in
                guard let self, let bounds = (NSScreen.screens.first { $0.frame.contains(point) }
                    ?? object?.panel.screen ?? NSScreen.main)?.visibleFrame else { return }
                if self.activeActivitySpot == spot { self.stopDailyAction() }
                self.activityWorld.move(spot, to: point, bounds: bounds)
                if self.activityWorld.requested == spot { self.actors.first?.motion.retarget() }
            }
            object.view.onMoveEnd = { [weak self] in
                guard let self, let actor = self.actors.first else { return }
                _ = self.triggerNearbyActivity(actor, now: Date())
            }
            desktopActivitySpots[spot] = object
        }
        home.view.onActivate = { [weak self] in
            guard let self else { return }
            if self.homeRoutine.isInside { self.wakeFromHome() } else { self.goHome() }
        }
        recordedVoice.onStatus = { [weak state] status in state?.voiceStatus = status }
        state.onVoicePreview = { [weak self] in self?.previewCharacterVoice() }
        state.onStopCharacterVoice = { [weak self] in self?.stopCharacterVoice() }
        state.onGoHome = { [weak self] in self?.goHome() }
        state.onWake = { [weak self] in self?.wakeFromHome() }
        state.onScatterItems = { [weak self] in self?.scatterItems() }
        state.onSeekItem = { [weak self] item in self?.seekItem(item) }
        state.onDropItem = { [weak self] in self?.dropItem() }
        state.onDailyAction = { [weak self] action in self?.playDailyAction(action) }
        state.onStopDailyAction = { [weak self] in self?.stopDailyAction() }
        state.onSeekActivitySpot = { [weak self] spot in self?.seekActivitySpot(spot) }
        resetPositions()
        if let visible = NSScreen.main?.visibleFrame {
            itemWorld.configure(enabled: state.enabledItems, bounds: visible)
            activityWorld.configure(enabled: state.enabledActivitySpots, bounds: visible)
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in self?.screenLayoutChanged() }
        guard startTimer else { return }
        timer = Timer(timeInterval: DesktopActivity.updateInterval, repeats: true) { [weak self] _ in self?.tick() }
        timer?.tolerance = 0.002
        RunLoop.main.add(timer!, forMode: .common)
    }
    deinit {
        timer?.invalidate()
        desktopActivitySpots.values.forEach { $0.panel.close() }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
    func resetPositions() {
        stopDailyAction()
        if homeRoutine.phase != .outside { wakeFromHome() }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        for (index, actor) in actors.enumerated() {
            let size = actor.panel.frame.size
            let origin = RoamingMotion.target(in: visible, size: size,
                                              xFraction: 0.18 + CGFloat(index) * 0.16, yFraction: 0.28)
            actor.panel.setFrameOrigin(origin)
            actor.motion.retarget()
            actor.motion.destination = RoamingMotion.target(in: visible, size: size, xFraction: 0.8, yFraction: 0.72)
        }
        itemTarget = nil
    }
    private func screenLayoutChanged() {
        resetPositions()
        home.anchorToScreen()
        // Repair coordinates only when the display layout actually changes.
        // Props already on another connected screen stay on that screen.
        for (item, point) in itemWorld.ground {
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { continue }
            itemWorld.move(item, to: point, bounds: screen.visibleFrame)
        }
        for (spot, point) in activityWorld.positions {
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { continue }
            activityWorld.move(spot, to: point, bounds: screen.visibleFrame)
        }
    }
    func seekActivitySpot(_ spot: ActivitySpot) {
        guard activityWorld.positions[spot] != nil else { return }
        stopDailyAction()
        if homeRoutine.phase != .outside { wakeFromHome() }
        state.roaming = true; state.showFriends = true
        actors.first?.dismissBubble(); stopCharacterVoice(); speech.stopSpeaking(at: .immediate)
        activityWorld.requested = spot; itemWorld.requested = nil; itemTarget = nil
        state.activityJourneyRunning = true
        actors.first?.performance.cancel(now: Date()); actors.first?.motion.retarget()
        state.dailyActionStatus = "\(spot.name) 쪽으로 걸어가는 중"
    }
    @discardableResult
    func triggerNearbyActivity(_ actor: FriendActor, now: Date) -> Bool {
        guard actor.dailyPerformance.action(now: now) == nil, !actor.view.isDragging,
              now >= actor.bubbleUntil, homeRoutine.phase == .outside,
              itemWorld.requested == nil || activityWorld.requested != nil else { return false }
        let contact = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
        activityWorld.observe(contact: contact)
        let dragged = Set(desktopActivitySpots.filter { $0.value.view.isDragging }.map(\.key))
        guard let spot = activityWorld.encounter(contact: contact, automatic: state.automaticActivities, now: now, excluding: dragged) else { return false }
        playDailyAction(spot.action, at: spot, now: now)
        return true
    }
    func seekItem(_ item: CompanionItem) {
        guard itemWorld.ground[item] != nil else { return }
        stopDailyAction()
        if homeRoutine.phase != .outside { wakeFromHome() }
        state.roaming = true; state.showFriends = true
        itemWorld.requested = item; itemTarget = nil
        actors.first?.performance.cancel(now: Date())
        actors.first?.motion.retarget()
        state.itemStatus = "\(item.name) 주우러 가는 중"
    }
    func scatterItems() {
        guard let bounds = NSScreen.main?.visibleFrame else { return }
        itemWorld.scatter(in: bounds); itemTarget = nil
        actors.first?.motion.retarget()
        state.itemStatus = "소품을 바탕화면에 다시 놓았어요"
    }
    func dropItem() {
        guard let actor = actors.first, let bounds = actor.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let point = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
        itemWorld.drop(at: NSPoint(x: point.x + 88, y: point.y), bounds: bounds, now: Date())
        actor.performance.cancel(now: Date()); itemWorld.requested = nil; itemTarget = nil
        actor.motion.retarget()
        publishEquipment()
        state.itemStatus = "소품을 내려놓았어요"
    }
    func handleCharacterClick(_ actor: FriendActor) {
        if actor.friend == .hachiware, let selected = ClickDialogue.choose(excluding: lastClickDialogueID) {
            presentClickDialogue(selected, for: actor)
        } else {
            presentClickDialogue(ClickDialogue(id: actor.friend.rawValue, text: actor.friend.greeting, recording: nil), for: actor)
        }
    }
    func presentClickDialogue(_ selected: ClickDialogue, for actor: FriendActor) {
        stopDailyAction()
        recordedVoice.stop()
        speech.stopSpeaking(at: .immediate)
        lastClickDialogueID = selected.id
        let line = selected.recording
        let duration = state.characterVoice ? max(4, (line?.duration ?? 0) + 0.35) : 4
        actor.say(selected.text, now: Date(), duration: duration)
        if state.characterVoice, let line {
            recordedVoice.play(line, volume: state.characterVolume)
        } else if !state.characterVoice {
            state.voiceStatus = "클릭 목소리를 꺼 두었어요"
        } else {
            state.voiceStatus = "이 명대사는 녹음이 없어 글로 보여줘요"
        }
    }
    func previewCharacterVoice() {
        stopDailyAction()
        guard let actor = actors.first else { return }
        if homeRoutine.phase != .outside { wakeFromHome() }
        guard let line = RecordingCatalog.shared.choose(excluding: lastRecordedLine) else {
            state.voiceStatus = "아직 준비된 녹음이 없어요"; return
        }
        lastRecordedLine = line.id
        speech.stopSpeaking(at: .immediate)
        if state.showFriends { actor.say(line.text, now: Date(), duration: max(4, line.duration + 0.35)) }
        // Explicit preview works while the click-voice switch is off, without changing that preference.
        recordedVoice.play(line, volume: state.characterVolume)
    }
    func stopCharacterVoice() {
        guard recordedVoice.player != nil else { return }
        recordedVoice.stop(); state.voiceStatus = "목소리 재생을 멈췄어요"
    }
    func playDailyAction(_ action: HachiwareAction, at sourceSpot: ActivitySpot? = nil, now: Date = Date()) {
        guard action.isDaily, let actor = actors.first else { return }
        if homeRoutine.phase != .outside { wakeFromHome(now: now) }
        state.showFriends = true
        if let index = state.assignments.firstIndex(where: { $0.friend == .hachiware }) {
            state.assignments[index].enabled = true
        }
        stopCharacterVoice(); speech.stopSpeaking(at: .immediate)
        actor.dismissBubble(); actor.performance.cancel(now: now)
        itemWorld.requested = nil; itemTarget = nil
        let contact = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
        let spot = sourceSpot ?? activityWorld.nearbySource(for: action, contact: contact)
        activityWorld.requested = nil; activeActivitySpot = spot
        state.activityJourneyRunning = false
        if let spot, let point = activityWorld.positions[spot] {
            // The selected pose already contains its table/bowl. Align its feet to
            // this prop's fixed anchor; never relocate the prop or any carried item.
            actor.panel.setFrameOrigin(ItemWorld.destination(for: point))
            activityWorld.consume(spot, now: now)
        }
        actor.dailyPerformance.begin(action, now: now); actor.motion.stop()
        actor.view.action = action; actor.view.actionTime = 0; actor.view.walking = false
        actor.view.needsDisplay = true; actor.panel.orderFrontRegardless()
        state.dailyActionRunning = true; state.dailyActionStatus = "\(action.title) · 끝나면 다시 산책해요"
    }
    func stopDailyAction() {
        activeActivitySpot = nil
        if state.activityJourneyRunning { state.activityJourneyRunning = false }
        if activityWorld.requested != nil { activityWorld.requested = nil; actors.first?.motion.retarget() }
        for actor in actors where actor.dailyPerformance.selected != nil {
            actor.dailyPerformance.cancel()
            if actor.view.action?.isDaily == true { actor.view.action = nil }
            actor.view.actionTime = nil; actor.motion.retarget(); actor.view.needsDisplay = true
        }
        if state.dailyActionRunning { state.dailyActionRunning = false }
        let status = "공부하고, 밥도 먹고, 잠깐 쉬어 가요"
        if state.dailyActionStatus != status { state.dailyActionStatus = status }
    }
    func goHome(now: Date = Date()) {
        guard !homeRoutine.isInside else { return }
        state.homeEnabled = true; state.showFriends = true; state.roaming = true
        requestHome(now: now)
    }
    private func requestHome(now: Date) {
        stopDailyAction()
        stopCharacterVoice()
        homeRoutine.request(now: now)
        actors.first?.motion.retarget(); actors.first?.performance.cancel(now: now)
        itemWorld.requested = nil; itemTarget = nil
        publishHome()
    }
    func wakeFromHome(now: Date = Date()) {
        let wasInside = homeRoutine.isInside
        homeRoutine.wake(now: now)
        if let actor = actors.first {
            if wasInside {
                let visible = home.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? home.panel.frame
                actor.panel.setFrameOrigin(DesktopGeometry.clamp(ItemWorld.destination(for: home.entrance),
                    size: actor.panel.frame.size, to: visible))
            }
            actor.motion.retarget(); actor.performance.cancel(now: now)
            // Step away before considering the doorway again. Waking never scatters props.
            if state.roaming && wasInside {
                actor.motion.destination = NSPoint(x: actor.panel.frame.minX - 180, y: actor.panel.frame.minY + 55)
            }
        }
        itemTarget = nil; publishHome()
    }
    private func publishHome() {
        if state.homeStatus != homeRoutine.status { state.homeStatus = homeRoutine.status }
        if state.resting != homeRoutine.isInside { state.resting = homeRoutine.isInside }
    }
    @discardableResult
    func enterHomeIfReached(_ actor: FriendActor, now: Date) -> Bool {
        guard state.homeEnabled, !actor.view.isDragging, now >= actor.bubbleUntil,
              activityWorld.requested == nil,
              actor.dailyPerformance.action(now: now) == nil,
              homeRoutine.arrive(contact: ItemWorld.contactPoint(origin: actor.panel.frame.origin),
                                 entrance: home.entrance, now: now) else { return false }
        // Only the carried item moves: the other desktop props retain their world coordinates.
        let visible = home.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? home.panel.frame
        itemWorld.drop(at: NSPoint(x: home.panel.frame.maxX + 24, y: home.entrance.y), bounds: visible, now: now)
        itemWorld.requested = nil; itemTarget = nil
        actor.motion.retarget(); actor.performance.cancel(now: now); actor.dismissBubble()
        actor.panel.orderOut(nil)
        publishEquipment(); publishHome()
        return true
    }
    private func publishEquipment() {
        if state.equippedItem != itemWorld.equipped { state.equippedItem = itemWorld.equipped }
    }
    func tick(now: Date = Date(), pointer: NSPoint? = nil) {
        let dt = min(max(0, now.timeIntervalSince(lastTick)), 0.06)
        lastTick = now
        let time = now.timeIntervalSince(started), mouse = pointer ?? NSEvent.mouseLocation
        recordedVoice.setVolume(state.characterVolume)
        if !state.showFriends { stopCharacterVoice() }
        if let bounds = NSScreen.main?.visibleFrame {
            let previous = itemWorld.equipped
            itemWorld.configure(enabled: state.enabledItems, bounds: bounds)
            if previous != itemWorld.equipped { actors.first?.performance.cancel(now: now) }
            publishEquipment()
            let request = activityWorld.requested
            activityWorld.configure(enabled: state.enabledActivitySpots, bounds: bounds)
            if let activeActivitySpot, !state.enabledActivitySpots.contains(activeActivitySpot) { stopDailyAction() }
            if request != activityWorld.requested {
                actors.first?.motion.retarget()
                state.activityJourneyRunning = activityWorld.requested != nil
            }
        }
        let homeVisible = state.homeEnabled && state.showFriends
            && (state.activeAssignments.first { $0.friend == .hachiware }?.enabled ?? false)
        if !homeVisible && homeRoutine.phase != .outside { wakeFromHome(now: now) }
        homeRoutine.advance(now: now)
        if homeRoutine.shouldWake(now: now) { wakeFromHome(now: now) }
        for actor in actors {
            let enabled = state.showFriends && (state.assignments.first { $0.friend == actor.friend }?.enabled ?? false)
            guard enabled else {
                stopDailyAction()
                actor.panel.orderOut(nil); actor.dismissBubble(); stopCharacterVoice()
                actor.performance.cancel(now: now)
                for item in desktopItems.values { item.update(position: nil, visible: false, mouse: mouse) }
                updateActivitySpots(visible: false, mouse: mouse, actor: actor)
                continue
            }
            if actor.dailyPerformance.selected != nil && actor.dailyPerformance.action(now: now) == nil {
                stopDailyAction()
            }
            if homeRoutine.isInside && now < actor.bubbleUntil { wakeFromHome(now: now) }
            if !homeRoutine.isInside { _ = enterHomeIfReached(actor, now: now) }
            if homeRoutine.isInside {
                actor.panel.orderOut(nil); actor.motion.stop()
                for (item, desktopItem) in desktopItems {
                    desktopItem.update(position: itemWorld.ground[item], visible: enabled, mouse: mouse)
                }
                updateActivitySpots(visible: enabled, mouse: mouse, actor: actor)
                continue
            }
            if !actor.panel.isVisible { actor.panel.orderFrontRegardless() }
            let hovered = actor.panel.occlusionState.contains(.visible)
                && DesktopGeometry.hit(mouse, in: actor.panel.frame)
            actor.panel.ignoresMouseEvents = !hovered && !actor.view.isDragging
            let activity = DesktopActivity.resolve(roaming: state.roaming, hovered: hovered,
                                                   dragging: actor.view.isDragging,
                                                   notificationUntil: actor.bubbleUntil, now: now)
            if activity == .dragging || activity == .notifying { stopDailyAction() }
            activityWorld.observe(contact: ItemWorld.contactPoint(origin: actor.panel.frame.origin))
            if activity == .walking || activity == .idle { _ = triggerNearbyActivity(actor, now: now) }
            let dailyAction = actor.dailyPerformance.action(now: now)
            if homeVisible && activity == .walking && itemWorld.requested == nil
                && activityWorld.requested == nil
                && dailyAction == nil
                && homeRoutine.shouldReturn(now: now, automatic: state.automaticRest, roaming: state.roaming) {
                requestHome(now: now)
            }
            if hovered && !actor.wasHovered { actor.hoverStarted = now }
            actor.wasHovered = hovered
            if dailyAction != nil || activity != .walking || !state.expressive || homeRoutine.phase == .returning { actor.performance.cancel(now: now) }
            if dailyAction == nil, activityWorld.requested == nil, activity == .walking, homeRoutine.phase != .returning, state.expressive, let item = itemWorld.equipped,
               now >= actor.performance.nextPerformance {
                actor.performance.begin(item, now: now, pickingUp: false)
            }
            var action = dailyAction ?? (state.expressive ? actor.performance.action(now: now) : nil)
            if activity == .walking && action == nil, let screen = actor.panel.screen ?? NSScreen.main {
                let frame = actor.panel.frame
                let draggedItems = Set(desktopItems.filter { $0.value.view.isDragging }.map(\.key))
                let targetItem = homeRoutine.phase == .returning || activityWorld.requested != nil ? nil : itemWorld.target(from: frame.origin, automatic: state.automaticItems,
                                                 now: now, excluding: draggedItems)
                if itemTarget != targetItem { actor.motion.retarget(); itemTarget = targetItem }
                if homeRoutine.phase == .returning {
                    actor.motion.destination = ItemWorld.destination(for: home.entrance)
                }
                if let spot = activityWorld.requested, let point = activityWorld.positions[spot] {
                    actor.motion.destination = ItemWorld.destination(for: point)
                }
                if let targetItem, let point = itemWorld.ground[targetItem] {
                    actor.motion.destination = ItemWorld.destination(for: point)
                    if itemWorld.pickUp(targetItem, from: frame.origin, bounds: screen.visibleFrame, now: now) {
                        actor.motion.retarget(); itemTarget = nil
                        if state.expressive {
                            actor.performance.begin(targetItem, now: now, pickingUp: true)
                            action = actor.performance.action(now: now)
                        }
                        state.itemStatus = "\(targetItem.name)를 주웠어요"
                        publishEquipment()
                    }
                }
                if actor.motion.destination == nil && action == nil {
                    var target = frame.origin
                    // Prefer a real journey, rather than pacing around a nearby point.
                    for _ in 0..<8 {
                        target = RoamingMotion.target(in: screen.visibleFrame, size: frame.size,
                                                      xFraction: .random(in: 0.03...0.97),
                                                      yFraction: .random(in: 0.03...0.97))
                        if hypot(target.x - frame.minX, target.y - frame.minY) > min(screen.visibleFrame.width, screen.visibleFrame.height) * 0.28 { break }
                    }
                    actor.motion.destination = target
                }
                if action == nil {
                    let travelBounds = homeRoutine.phase == .returning
                        ? screen.visibleFrame.union(home.panel.screen?.visibleFrame ?? screen.visibleFrame) : screen.visibleFrame
                    let position = actor.motion.advance(from: frame.origin, dt: dt, bounds: travelBounds, size: frame.size)
                    actor.panel.setFrameOrigin(position)
                }
                // AppKit can round or constrain the requested position. Animate only the
                // displacement actually shown on screen, including its diagonal component.
                actor.gait.recordMovement(from: frame.origin, to: actor.panel.frame.origin)
                _ = enterHomeIfReached(actor, now: now)
                if triggerNearbyActivity(actor, now: now) { action = actor.dailyPerformance.action(now: now) }
            } else { actor.motion.stop() }
            actor.view.time = time + actor.phase
            actor.view.walking = actor.motion.isWalking
            actor.view.facing = actor.motion.facing
            actor.view.walkPhase = actor.gait.phase
            actor.view.pose = HachiwarePose.forVelocity(actor.motion.velocity)
            actor.view.happy = activity.reacts
            if dailyAction == nil && state.expressive && activity == .hovering {
                action = now.timeIntervalSince(actor.hoverStarted) < 0.3 ? .wave : .laugh
            } else if state.expressive && activity == .notifying {
                action = .surprised
            }
            actor.view.action = action
            actor.view.actionTime = actor.dailyPerformance.action(now: now) == nil ? nil : actor.dailyPerformance.elapsed(now: now)
            actor.view.equipped = itemWorld.equipped
            actor.view.looking = min(1, max(-1, (mouse.x - actor.panel.frame.midX) / 160))
            actor.view.needsDisplay = true
            if now < actor.bubbleUntil { actor.positionBubble() }
            else if actor.bubble != nil { actor.dismissBubble() }
            for (item, desktopItem) in desktopItems {
                desktopItem.update(position: itemWorld.ground[item], visible: enabled, mouse: mouse)
            }
            updateActivitySpots(visible: enabled, mouse: mouse, actor: actor)
        }
        publishHome()
        let homeWasVisible = home.panel.isVisible
        home.update(visible: homeVisible, mouse: mouse, routine: homeRoutine, now: now, time: time)
        if !homeWasVisible && homeVisible && !homeRoutine.isInside {
            actors.filter { $0.panel.isVisible }.forEach { $0.panel.order(.above, relativeTo: home.panel.windowNumber) }
        }
    }
    private func updateActivitySpots(visible: Bool, mouse: NSPoint, actor: FriendActor) {
        for (spot, object) in desktopActivitySpots {
            let replacedByPose = activeActivitySpot == spot && spot != .furball && actor.dailyPerformance.selected != nil
            object.update(position: activityWorld.positions[spot], visible: visible && !replacedByPose,
                          mouse: mouse, behind: actor.panel.isVisible ? actor.panel.windowNumber : nil)
        }
    }
    func notify(_ friend: Friend, sender: String, body: String? = nil, demo: Bool = false) {
        guard let actor = actors.first(where: { $0.friend == friend }) else { return }
        guard state.showFriends, state.activeAssignments.contains(where: { $0.friend == friend && $0.enabled }) else { return }
        stopDailyAction()
        if homeRoutine.phase != .outside { wakeFromHome() }
        stopCharacterVoice()
        let alert = KakaoAlertPresentation(sender: sender, body: body, demo: demo)
        let duration = min(12, max(6, Double(alert.message.count) / 25))
        actor.say(alert.message, now: Date(), duration: duration, heading: alert.title)
        if state.voice {
            speech.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: alert.spokenText)
            utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
            utterance.rate = 0.48
            speech.speak(utterance)
        }
    }
}
