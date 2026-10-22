import AppKit

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
    static func repairedOrigin(_ origin: NSPoint, size: NSSize, visibleFrames: [NSRect]) -> NSPoint {
        visibleFrames.map { clamp(origin, size: size, to: $0) }.min {
            hypot($0.x - origin.x, $0.y - origin.y) < hypot($1.x - origin.x, $1.y - origin.y)
        } ?? origin
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
    var rosterVisual: RosterVisual?
    var onRosterAction: ((RosterAction) -> Void)?
    var chiikawaItem: ChiikawaItem?
    var previousChiikawaReaction: ChiikawaReaction?
    var chiikawaReactionChanged = -Double.infinity
    var chiikawaReaction: ChiikawaReaction? {
        didSet {
            if oldValue != chiikawaReaction { previousChiikawaReaction = oldValue; chiikawaReactionChanged = time }
        }
    }
    var chiikawaLife: ChiikawaLifeAction?
    var attackUsesOverlay = false
    var isDragging = false
    var onClick: (() -> Void)?
    var onToggleWalking: (() -> Void)?
    var onDropEquipment: (() -> Void)?
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?
    var onDailyAction: ((HachiwareAction) -> Void)?
    var onStopDailyAction: (() -> Void)?
    var onChiikawaLife: ((ChiikawaLifeAction) -> Void)?
    var onGoHome: (() -> Void)?
    private var downPoint: NSPoint = .zero
    private var downOrigin: NSPoint = .zero
    private var moved = false

    init(friend: Friend) {
        self.friend = friend
        super.init(frame: NSRect(origin: .zero, size: friend.actorSize))
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("\(friend.name) — 클릭해 인사하기, 드래그로 이동, 우클릭해 동작 고르기.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onClick?(); return true }
    override func draw(_ dirtyRect: NSRect) {
        // The transparent actor remains the pointer target while the attack
        // overlay paints the body. Remove the previous pose from its backing.
        NSGraphicsContext.current?.cgContext.clear(bounds)
        if action == .attack && attackUsesOverlay { return }
        FriendArtwork.draw(friend, in: bounds, time: time, happy: happy, walking: walking,
                           looking: looking, facing: facing, walkPhase: walkPhase, pose: pose,
                           action: action, equipped: equipped, actionTime: actionTime,
                           chiikawaReaction: chiikawaReaction, chiikawaItem: chiikawaItem, chiikawaLife: chiikawaLife,
                           previousChiikawaReaction: previousChiikawaReaction, reactionProgress: min(1,max(0,(time-chiikawaReactionChanged)/0.1)), rosterVisual: rosterVisual)
    }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        if friend.isExpansion {
            for action in RosterAction.selectable {
                let entry = NSMenuItem(title: action.title, action: #selector(chooseRosterAction(_:)), keyEquivalent: "")
                entry.target = self; entry.representedObject = action.rawValue; menu.addItem(entry)
            }
            for (title, selector) in [("집으로 가서 자기", #selector(goHome)), ("동작 멈추기", #selector(stopDailyAction)),
                ("이 친구 산책 켜기 / 끄기", #selector(toggleWalking)), ("소품 내려놓기", #selector(dropEquipment))] {
                let entry = NSMenuItem(title: title, action: selector, keyEquivalent: ""); entry.target = self; menu.addItem(entry)
            }
            NSMenu.popUpContextMenu(menu, with: event, for: self); return
        }
        for action in friend == .hachiware ? HachiwareAction.daily : [] {
            let entry = NSMenuItem(title: action.title, action: #selector(chooseDailyAction(_:)), keyEquivalent: "")
            entry.target = self; entry.tag = action.rawValue; menu.addItem(entry)
        }
        if friend == .chiikawa {
            for action in ChiikawaLifeAction.allCases {
                let entry = NSMenuItem(title: action.title, action: #selector(chooseChiikawaLife(_:)), keyEquivalent: "")
                entry.target = self; entry.representedObject = action.rawValue; menu.addItem(entry)
            }
            let home = NSMenuItem(title: "집으로 가서 자기", action: #selector(goHome), keyEquivalent: "")
            home.target = self; menu.addItem(home)
            let stop = NSMenuItem(title: "동작 멈추기", action: #selector(stopDailyAction), keyEquivalent: "")
            stop.target = self; menu.addItem(stop); menu.addItem(.separator())
            let walk = NSMenuItem(title: "이 친구 산책 켜기 / 끄기", action: #selector(toggleWalking), keyEquivalent: "")
            walk.target = self; menu.addItem(walk)
            let drop = NSMenuItem(title: "소품 내려놓기", action: #selector(dropEquipment), keyEquivalent: "")
            drop.target = self; menu.addItem(drop)
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }
        menu.addItem(.separator())
        let stop = NSMenuItem(title: "동작 멈추기", action: #selector(stopDailyAction), keyEquivalent: "")
        stop.target = self; menu.addItem(stop)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    @objc private func chooseRosterAction(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let action = RosterAction(rawValue: value) else { return }
        onRosterAction?(action)
    }
    @objc private func chooseDailyAction(_ sender: NSMenuItem) {
        guard let action = HachiwareAction(rawValue: sender.tag), action.isDaily else { return }
        onDailyAction?(action)
    }
    @objc private func toggleWalking() { onToggleWalking?() }
    @objc private func goHome() { onGoHome?() }
    @objc private func chooseChiikawaLife(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = ChiikawaLifeAction(rawValue: raw) else { return }
        onChiikawaLife?(action)
    }
    @objc private func dropEquipment() { onDropEquipment?() }
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
    let attackOverlay: AttackOverlay
    var motion = RoamingMotion()
    var gait = WalkingGait()
    let phase: Double
    var bubble: NSPanel?
    var bubbleUntil = Date.distantPast
    var performance = CompanionPerformance()
    var dailyPerformance = DailyActionPerformance()
    var hoverStarted = Date.distantPast
    var wasHovered = false
    var lastGreeting: String?
    var clickReaction = ChiikawaReaction.happy
    var armedHoverContact: CharacterPointerMask?

    init(friend: Friend, index: Int) {
        self.friend = friend
        attackOverlay = AttackOverlay(friend: friend)
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
    func say(_ text: String, now: Date, duration: TimeInterval = 4) {
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
        p.title = "\(friend.name) 대사"
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
        let title = NSTextField(labelWithString: friend.name)
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
    var expansions: [Friend: RosterCompanion] = [:]
    let state: AppState
    var actors: [FriendActor] = []
    var hachiwareActor: FriendActor? { actors.first { $0.friend == .hachiware } }
    var chiikawaActor: FriendActor? { actors.first { $0.friend == .chiikawa } }
    var chiikawaWorld = PropWorld<ChiikawaItem>()
    var chiikawaDesktopItems: [ChiikawaItem: DesktopPropWindow<ChiikawaItem>] = [:]
    var chiikawaItemTarget: ChiikawaItem?
    // One house, independent rest clocks for all current and future friends.
    var homeRoutines: [Friend: HomeRoutine] = [:]
    var chiikawaHomeRoutine: HomeRoutine {
        get { homeRoutines[.chiikawa] ?? HomeRoutine(now: started) }
        set { homeRoutines[.chiikawa] = newValue }
    }
    var chiikawaSeekingHomeKey = false
    var chiikawaWakingAt: Date?
    let chiikawaFood = DesktopActivitySpot(spot: .rice, owner: .chiikawa)
    let chiikawaDesk = DesktopActivitySpot(spot: .desk, owner: .chiikawa)
    var chiikawaStudyWorld = ActivitySpotWorld()
    var chiikawaLifeRoutine = ChiikawaLifeRoutine()
    var chiikawaStudyingAtDesk = false
    let chiikawaVoice: RecordedVoicePlayer
    var lastChiikawaVoiceID: String?
    var timer: Timer?
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
    var homeRoutine: HomeRoutine {
        get { homeRoutines[.hachiware] ?? HomeRoutine(now: started) }
        set { homeRoutines[.hachiware] = newValue }
    }

    init(state: AppState, startTimer: Bool = true, recordedVoice: RecordedVoicePlayer = RecordedVoicePlayer(),
         chiikawaVoice: RecordedVoicePlayer = RecordedVoicePlayer(idleStatus: "클릭하면 치이카와의 짧은 반응을 들려줘요"),
         expansionVoice: (Friend) -> RecordedVoicePlayer = { _ in RecordedVoicePlayer(idleStatus: "클릭할 때만 녹음을 재생해요") }) {
        self.state = state
        self.recordedVoice = recordedVoice
        self.chiikawaVoice = chiikawaVoice
        // Decode and register once at launch, never on the first pointer hover.
        _ = ChiikawaAttackSprites.shared
        _ = ChiikawaSprites.shared
        _ = ChiikawaMotionSprites.shared
        _ = ChiikawaBlinkArtwork.shared
        _ = HachiwareSprites.shared
        _ = HachiwareActions.shared
        _ = WeaponAttackSprites.shared
        actors = Friend.developmentRoster.enumerated().map { FriendActor(friend: $0.element, index: $0.offset) }
        for actor in actors {
            actor.view.onClick = { [weak self, weak actor] in
                guard let self, let actor else { return }
                self.handleCharacterClick(actor)
            }
            actor.view.onToggleWalking = { [weak self, weak actor] in
                guard let self, let actor else { return }
                if self.state.walkingFriends.contains(actor.friend) { self.state.walkingFriends.remove(actor.friend) }
                else { self.state.walkingFriends.insert(actor.friend); self.state.roaming = true }
            }
            if actor.friend == .chiikawa {
                actor.view.onDropEquipment = { [weak self] in self?.dropChiikawaItem() }
                actor.view.onChiikawaLife = { [weak self] action in self?.playChiikawaLife(action) }
                actor.view.onGoHome = { [weak self] in self?.goChiikawaHome() }
                actor.view.onStopDailyAction = { [weak self] in self?.stopChiikawaLife() }
            }
            actor.view.onDragStart = { [weak self, weak actor] in
                guard let actor else { return }
                actor.dismissBubble(); actor.motion.stop()
                if actor.friend == .chiikawa {
                    self?.stopChiikawaLife(); self?.stopChiikawaVoice()
                    if self?.chiikawaHomeRoutine.phase == .returning { self?.wakeChiikawa() }
                    return
                }
                guard actor.friend == .hachiware else { return }
                self?.stopCharacterVoice()
                self?.stopDailyAction()
                guard let self, self.homeRoutine.phase == .returning else { return }
                self.wakeFromHome()
            }
            if actor.friend == .hachiware {
                actor.view.onDailyAction = { [weak self] action in self?.playDailyAction(action) }
                actor.view.onStopDailyAction = { [weak self] in self?.stopDailyAction() }
            }
            actor.view.onDragEnd = { [weak self, weak actor] in
                actor?.motion.retarget()
                if let actor, actor.friend == .chiikawa { self?.didMoveChiikawa(actor); return }
                // Ground props own screen coordinates. Moving the character only
                // invalidates its route; it must never reposition those props.
                self?.itemTarget = nil
                if let self, let actor, self.triggerNearbyActivity(actor, now: Date()) { return }
                if let self, let actor {
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
        configureChiikawaItems()
        configureChiikawaLife()
        for item in CompanionItem.allCases {
            let desktopItem = DesktopItem(item: item)
            desktopItem.view.onSeek = { [weak self] in self?.seekItem(item) }
            desktopItem.view.onMove = { [weak self, weak desktopItem] point in
                guard let self, let bounds = (NSScreen.screens.first { $0.frame.contains(point) }
                    ?? desktopItem?.panel.screen ?? NSScreen.main)?.visibleFrame else { return }
                self.itemWorld.move(item, to: point, bounds: bounds)
            }
            desktopItem.view.onMoveEnd = { [weak self] point in
                _ = self?.receiveDroppedItem(item, at: point)
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
                if self.activityWorld.requested == spot { self.hachiwareActor?.motion.retarget() }
            }
            object.view.onMoveEnd = { [weak self] in
                guard let self, let actor = self.hachiwareActor else { return }
                _ = self.triggerNearbyActivity(actor, now: Date())
            }
            desktopActivitySpots[spot] = object
        }
        home.view.onActivate = { [weak self] in
            guard let self else { return }
            self.activateSharedHome()
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
        state.onCallFriend = { [weak self] friend in self?.callFriend(friend) }
        for actor in actors where actor.friend.isExpansion {
            _ = RosterSprites.shared(actor.friend)
            let companion = RosterCompanion(desktop: self, actor: actor, voice: expansionVoice(actor.friend))
            expansions[actor.friend] = companion
            actor.view.onDragStart = { [weak companion] in companion?.beganDragging() }
            actor.view.onDragEnd = { [weak companion] in companion?.endedDragging() }
        }
        state.onRosterCommand = { [weak self] friend, command in self?.expansions[friend]?.command(command) }
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
        expansions.values.forEach { $0.close() }
        actors.forEach { $0.dismissBubble(); $0.panel.close(); $0.attackOverlay.panel.close() }
        desktopItems.values.forEach { $0.panel.close() }
        chiikawaDesktopItems.values.forEach { $0.panel.close() }
        chiikawaDesk.panel.close(); chiikawaFood.panel.close(); chiikawaVoice.stop()
        home.panel.close()
        desktopActivitySpots.values.forEach { $0.panel.close() }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
    func resetPositions() {
        expansions.values.forEach { $0.stopAction(); $0.wake() }
        stopDailyAction()
        stopChiikawaLife()
        if chiikawaHomeRoutine.phase != .outside || chiikawaWakingAt != nil { wakeChiikawa() }
        if homeRoutine.phase != .outside { wakeFromHome() }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        for (index, actor) in actors.enumerated() {
            let size = actor.panel.frame.size
            let origin = RoamingMotion.target(in: visible, size: size,
                                              xFraction: 0.18 + CGFloat(index) * 0.16, yFraction: 0.28)
            actor.panel.setFrameOrigin(origin)
            actor.armedHoverContact = nil; actor.wasHovered = false
            actor.motion.retarget()
            actor.motion.destination = RoamingMotion.target(in: visible, size: size, xFraction: 0.8, yFraction: 0.72)
        }
        itemTarget = nil; chiikawaItemTarget = nil
    }
    private func screenLayoutChanged() {
        let frames = NSScreen.screens.map(\.visibleFrame)
        for actor in actors {
            let current = actor.panel.frame.origin
            let repaired = DesktopGeometry.repairedOrigin(current, size: actor.panel.frame.size, visibleFrames: frames)
            if repaired != current {
                actor.panel.setFrameOrigin(repaired)
                actor.motion.retarget()
            }
        }
        home.anchorToScreen()
        expansions.values.forEach { $0.repairScreenCoordinates() }
        for (spot,point) in chiikawaStudyWorld.positions {
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { continue }
            chiikawaStudyWorld.move(spot,to: point,bounds: screen.visibleFrame)
        }
        // Repair coordinates only when the display layout actually changes.
        // Props already on another connected screen stay on that screen.
        for (item, point) in itemWorld.ground {
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { continue }
            itemWorld.move(item, to: point, bounds: screen.visibleFrame)
        }
        for (item, point) in chiikawaWorld.ground {
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { continue }
            chiikawaWorld.move(item, to: point, bounds: screen.visibleFrame)
        }
        for (spot, point) in activityWorld.positions {
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else { continue }
            activityWorld.move(spot, to: point, bounds: screen.visibleFrame)
        }
    }
    func seekActivitySpot(_ spot: ActivitySpot, now: Date = Date()) {
        guard activityWorld.positions[spot] != nil else { return }
        stopDailyAction()
        if homeRoutine.phase != .outside { wakeFromHome(now: now) }
        state.roaming = true; state.showFriends = true
        state.visibleFriends.insert(.hachiware); state.walkingFriends.insert(.hachiware)
        hachiwareActor?.dismissBubble(); stopCharacterVoice()
        activityWorld.requested = spot; itemWorld.requested = nil; itemTarget = nil
        state.activityJourneyRunning = true
        hachiwareActor?.performance.cancel(now: now); hachiwareActor?.motion.retarget()
        state.dailyActionStatus = "\(spot.name) 쪽으로 걸어가는 중"
    }
    @discardableResult
    func triggerNearbyActivity(_ actor: FriendActor, now: Date) -> Bool {
        guard actor.friend == .hachiware, actor.dailyPerformance.action(now: now) == nil, !actor.view.isDragging,
              now >= actor.bubbleUntil, homeRoutine.phase == .outside,
              itemWorld.requested == nil || activityWorld.requested != nil else { return false }
        let contact = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
        activityWorld.observe(contact: contact)
        let dragged = Set(desktopActivitySpots.filter { $0.value.view.isDragging }.map(\.key))
        guard let spot = activityWorld.encounter(contact: contact, automatic: state.automaticActivities, now: now, excluding: dragged) else { return false }
        if !activityWorld.hasArrived(at: spot, contact: contact) {
            guard state.isWalking(.hachiware) else { return false }
            if activityWorld.requested != spot { seekActivitySpot(spot, now: now) }
            return false
        }
        playDailyAction(spot.action, at: spot, now: now)
        return true
    }
    func seekItem(_ item: CompanionItem) {
        guard itemWorld.ground[item] != nil else { return }
        stopDailyAction()
        if homeRoutine.phase != .outside { wakeFromHome() }
        state.roaming = true; state.showFriends = true
        state.visibleFriends.insert(.hachiware); state.walkingFriends.insert(.hachiware)
        itemWorld.requested = item; itemTarget = nil
        hachiwareActor?.performance.cancel(now: Date())
        hachiwareActor?.motion.retarget()
        state.itemStatus = "\(item.name) 주우러 가는 중"
    }
    func scatterItems() {
        guard let bounds = NSScreen.main?.visibleFrame else { return }
        itemWorld.scatter(in: bounds); itemTarget = nil
        hachiwareActor?.motion.retarget()
        state.itemStatus = "소품을 바탕화면에 다시 놓았어요"
    }
    @discardableResult
    func receiveDroppedItem(_ item: CompanionItem, at point: NSPoint, now: Date = Date()) -> Bool {
        guard state.isVisible(.hachiware), state.enabledItems.contains(item),
              let actor = hachiwareActor, actor.panel.isVisible,
              !actor.view.isDragging, !homeRoutine.isInside,
              desktopItems[item]?.view.isDragging == false,
              DesktopGeometry.hit(point, in: actor.panel.frame),
              let bounds = actor.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame,
              itemWorld.equip(item, at: actor.panel.frame.origin, bounds: bounds, now: now) else { return false }
        stopDailyAction()
        if homeRoutine.phase == .returning { wakeFromHome(now: now) }
        itemTarget = nil; actor.motion.retarget()
        actor.performance.cancel(now: now)
        if state.expressive && now >= actor.bubbleUntil { actor.performance.begin(item, now: now, pickingUp: false) }
        actor.view.equipped = item; actor.view.walking = false; actor.view.actionTime = nil
        actor.view.action = state.expressive
            ? (now < actor.bubbleUntil ? .surprised : actor.performance.action(now: now)) : nil
        actor.view.needsDisplay = true
        desktopItems[item]?.panel.orderOut(nil)
        publishEquipment()
        state.itemStatus = "\(item.name)를 건네받았어요"
        return true
    }
    func dropItem() {
        guard let actor = hachiwareActor, let bounds = actor.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let point = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
        itemWorld.drop(at: NSPoint(x: point.x + 88, y: point.y), bounds: bounds, now: Date())
        actor.performance.cancel(now: Date()); itemWorld.requested = nil; itemTarget = nil
        actor.motion.retarget()
        publishEquipment()
        state.itemStatus = "소품을 내려놓았어요"
    }
    @discardableResult
    func pickUpItem(_ item: CompanionItem, for actor: FriendActor, bounds: NSRect, now: Date) -> Bool {
        guard actor.friend == .hachiware, itemWorld.pickUp(item,from:actor.panel.frame.origin,bounds:bounds,now:now) else { return false }
        actor.motion.retarget(); itemTarget = nil
        if state.expressive { actor.performance.begin(item,now:now,pickingUp:true) }
        state.itemStatus = "\(item.name)를 주웠어요"
        publishEquipment()
        return true
    }
    func handleCharacterClick(_ actor: FriendActor) {
        if let companion = expansions[actor.friend] { companion.clicked(); return }
        if actor.friend == .hachiware, let selected = ClickDialogue.choose(excluding: lastClickDialogueID) {
            presentClickDialogue(selected, for: actor)
        } else if actor.friend == .chiikawa {
            sayChiikawa()
        }
    }
    func presentClickDialogue(_ selected: ClickDialogue, for actor: FriendActor) {
        guard actor.friend == .hachiware else { actor.say(selected.text, now: Date()); return }
        stopDailyAction()
        recordedVoice.stop()
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
        guard let actor = hachiwareActor else { return }
        if homeRoutine.phase != .outside { wakeFromHome() }
        guard let line = RecordingCatalog.shared.choose(excluding: lastRecordedLine) else {
            state.voiceStatus = "아직 준비된 녹음이 없어요"; return
        }
        lastRecordedLine = line.id
        if state.isVisible(.hachiware) { actor.say(line.text, now: Date(), duration: max(4, line.duration + 0.35)) }
        // Explicit preview works while the click-voice switch is off, without changing that preference.
        recordedVoice.play(line, volume: state.characterVolume)
    }
    func stopCharacterVoice() {
        guard recordedVoice.player != nil else { return }
        recordedVoice.stop(); state.voiceStatus = "목소리 재생을 멈췄어요"
    }
    func playDailyAction(_ action: HachiwareAction, at sourceSpot: ActivitySpot? = nil, now: Date = Date()) {
        guard action.isDaily, let actor = hachiwareActor else { return }
        let contact = ItemWorld.contactPoint(origin: actor.panel.frame.origin)
        let spot = sourceSpot ?? activityWorld.nearbySource(for: action, contact: contact)
        if let spot, !activityWorld.hasArrived(at: spot, contact: contact) {
            seekActivitySpot(spot, now: now); return
        }
        if homeRoutine.phase != .outside { wakeFromHome(now: now) }
        state.showFriends = true; state.visibleFriends.insert(.hachiware)
        stopCharacterVoice()
        actor.dismissBubble(); actor.performance.cancel(now: now)
        itemWorld.requested = nil; itemTarget = nil
        activityWorld.requested = nil; activeActivitySpot = spot
        state.activityJourneyRunning = false
        if let spot, activityWorld.positions[spot] != nil {
            // The final approach has already reached the prop. Begin at the
            // displayed position instead of snapping the window to its anchor.
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
        if activityWorld.requested != nil { activityWorld.requested = nil; hachiwareActor?.motion.retarget() }
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
        state.showFriends = true; state.roaming = true
        state.visibleFriends.insert(.hachiware); state.walkingFriends.insert(.hachiware)
        requestHome(now: now)
    }
    private func requestHome(now: Date) {
        stopDailyAction()
        stopCharacterVoice()
        homeRoutine.request(now: now)
        hachiwareActor?.motion.retarget(); hachiwareActor?.performance.cancel(now: now)
        itemWorld.requested = nil; itemTarget = nil
        publishHome()
    }
    func wakeFromHome(now: Date = Date()) {
        let wasInside = homeRoutine.isInside
        homeRoutine.wake(now: now)
        if let actor = hachiwareActor {
            if wasInside {
                let visible = home.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? home.panel.frame
                actor.panel.setFrameOrigin(DesktopGeometry.clamp(ItemWorld.destination(for: home.entrance),
                    size: actor.panel.frame.size, to: visible))
            }
            actor.motion.retarget(); actor.performance.cancel(now: now)
            // Step away before considering the doorway again. Waking never scatters props.
            if state.isWalking(.hachiware) && wasInside {
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
        guard actor.friend == .hachiware, !actor.view.isDragging, now >= actor.bubbleUntil,
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
    func tick(now: Date = Date(), pointer: NSPoint? = nil, pointerCanReachCharacter: Bool? = nil) {
        let dt = min(max(0, now.timeIntervalSince(lastTick)), 0.06)
        lastTick = now
        let time = now.timeIntervalSince(started), mouse = pointer ?? NSEvent.mouseLocation
        recordedVoice.setVolume(state.characterVolume)
        chiikawaVoice.setVolume(state.characterVolume)
        if !state.showFriends { stopCharacterVoice(); stopChiikawaVoice() }
        if let bounds = NSScreen.main?.visibleFrame {
            let previous = itemWorld.equipped
            itemWorld.configure(enabled: state.enabledItems, bounds: bounds)
            if previous != itemWorld.equipped { hachiwareActor?.performance.cancel(now: now) }
            publishEquipment()
            let request = activityWorld.requested
            activityWorld.configure(enabled: state.enabledActivitySpots, bounds: bounds)
            if let activeActivitySpot, !state.enabledActivitySpots.contains(activeActivitySpot) { stopDailyAction() }
            if request != activityWorld.requested {
                hachiwareActor?.motion.retarget()
                state.activityJourneyRunning = activityWorld.requested != nil
            }
        }
        let homeVisible = state.showFriends
        if !state.isVisible(.hachiware) && homeRoutine.phase != .outside { wakeFromHome(now: now) }
        homeRoutine.advance(now: now)
        if homeRoutine.shouldWake(now: now) { wakeFromHome(now: now) }
        for actor in actors {
            if let companion = expansions[actor.friend] {
                companion.tick(now: now, dt: dt, time: time, mouse: mouse, pointerCanReachCharacter: pointerCanReachCharacter)
                continue
            }
            if actor.friend == .chiikawa {
                tickChiikawa(actor, now: now, dt: dt, time: time, mouse: mouse, pointerCanReachCharacter: pointerCanReachCharacter)
                continue
            }
            let enabled = state.isVisible(actor.friend)
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
            let hovered = actor.pointerIsHovering(at: mouse,
                armed: state.expressive && itemWorld.equipped == .sasumata, canReach: pointerCanReachCharacter)
            actor.panel.ignoresMouseEvents = !hovered && !actor.view.isDragging
            let activity = DesktopActivity.resolve(roaming: state.isWalking(actor.friend), hovered: hovered,
                                                   dragging: actor.view.isDragging,
                                                   dialogueUntil: actor.bubbleUntil, now: now)
            if activity == .dragging || activity == .speaking { stopDailyAction() }
            activityWorld.observe(contact: ItemWorld.contactPoint(origin: actor.panel.frame.origin))
            if activity == .walking || activity == .idle { _ = triggerNearbyActivity(actor, now: now) }
            let dailyAction = actor.dailyPerformance.action(now: now)
            if homeVisible && activity == .walking && itemWorld.requested == nil
                && activityWorld.requested == nil
                && dailyAction == nil
                && homeRoutine.shouldReturn(now: now, automatic: state.automaticRest, roaming: state.isWalking(.hachiware)) {
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
                let followingRoute = homeRoutine.phase == .returning || activityWorld.requested != nil
                let nearbyItem = followingRoute ? nil : itemWorld.nearbyTarget(from:frame.origin,
                    automatic:state.automaticItems,now:now,excluding:draggedItems)
                let targetItem = followingRoute ? nil : nearbyItem ?? itemWorld.target(from: frame.origin, automatic: state.automaticItems,
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
                    if pickUpItem(targetItem,for:actor,bounds:screen.visibleFrame,now:now) {
                        action = state.expressive ? actor.performance.action(now:now) : nil
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
                    let position = actor.motion.advance(from: frame.origin, dt: dt, bounds: travelBounds, size: frame.size,
                        stoppingDistance: activityWorld.requested == nil ? 5 : ActivitySpotWorld.stoppingDistance)
                    actor.panel.setFrameOrigin(position)
                }
                // AppKit can round or constrain the requested position. Animate only the
                // displacement actually shown on screen, including its diagonal component.
                actor.gait.recordMovement(from: frame.origin, to: actor.panel.frame.origin)
                _ = enterHomeIfReached(actor, now: now)
                if triggerNearbyActivity(actor, now: now) { action = actor.dailyPerformance.action(now: now) }
                if action == nil && !homeRoutine.isInside && !followingRoute,
                   let nearbyItem = itemWorld.nearbyTarget(from:actor.panel.frame.origin,
                       automatic:state.automaticItems,now:now,excluding:draggedItems),
                   pickUpItem(nearbyItem,for:actor,bounds:screen.visibleFrame,now:now) {
                    action = state.expressive ? actor.performance.action(now:now) : nil
                }
            } else { actor.motion.stop() }
            actor.view.time = time + actor.phase
            actor.view.walking = actor.motion.isWalking
            actor.view.facing = actor.motion.facing
            actor.view.walkPhase = actor.gait.phase
            actor.view.pose = HachiwarePose.forVelocity(actor.motion.velocity)
            actor.view.happy = activity.reacts
            if dailyAction == nil && state.expressive && activity == .hovering && !actor.view.isDragging {
                action = HachiwareAction.hover(equipped: itemWorld.equipped, elapsed: now.timeIntervalSince(actor.hoverStarted))
            } else if state.expressive && activity == .speaking {
                action = .surprised
            }
            if action == .attack && actor.view.action != .attack { actor.hoverStarted = now }
            actor.view.action = action
            actor.view.actionTime = actor.dailyPerformance.action(now: now) == nil ? nil : actor.dailyPerformance.elapsed(now: now)
            if action == .attack { actor.view.actionTime = max(0, now.timeIntervalSince(actor.hoverStarted)) }
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
        home.update(visible: homeVisible, mouse: mouse, style: state.homeStyle, occupants: homeOccupants, now: now, time: time)
        if !homeWasVisible && homeVisible {
            actors.filter { $0.panel.isVisible }.forEach { $0.panel.order(.above, relativeTo: home.panel.windowNumber) }
        }
        actors.forEach { $0.attackOverlay.update(actor: $0) }
    }
    private func updateActivitySpots(visible: Bool, mouse: NSPoint, actor: FriendActor) {
        for (spot, object) in desktopActivitySpots {
            let replacedByPose = activeActivitySpot == spot && spot != .furball && actor.dailyPerformance.selected != nil
            object.update(position: activityWorld.positions[spot], visible: visible && !replacedByPose,
                          mouse: mouse, behind: actor.panel.isVisible ? actor.panel.windowNumber : nil)
        }
    }
}
