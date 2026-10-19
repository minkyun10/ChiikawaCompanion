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
    var equipped: CompanionItem?
    var isDragging = false
    var onClick: (() -> Void)?
    var onDragEnd: (() -> Void)?
    private var downPoint: NSPoint = .zero
    private var downOrigin: NSPoint = .zero
    private var moved = false

    init(friend: Friend) {
        self.friend = friend
        super.init(frame: NSRect(x: 0, y: 0, width: 132, height: 150))
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("\(friend.name) — 마우스를 올리거나 클릭해 인사하기. 드래그로 이동.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        FriendArtwork.draw(friend, in: bounds, time: time, happy: happy, walking: walking,
                           looking: looking, facing: facing, walkPhase: walkPhase, pose: pose,
                           action: action, equipped: equipped)
    }
    override func mouseDown(with event: NSEvent) {
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
    let started = Date()
    var lastTick = Date()
    var screenObserver: NSObjectProtocol?
    var itemWorld = ItemWorld()
    var desktopItems: [CompanionItem: DesktopItem] = [:]
    var itemTarget: CompanionItem?

    init(state: AppState) {
        self.state = state
        // Decode and register once at launch, never on the first pointer hover.
        _ = HachiwareSprites.shared
        _ = HachiwareActions.shared
        actors = Friend.developmentRoster.enumerated().map { FriendActor(friend: $0.element, index: $0.offset) }
        for actor in actors {
            actor.view.onClick = { [weak actor] in
                actor?.say(actor?.friend.greeting ?? "안녕!", now: Date())
            }
            actor.view.onDragEnd = { [weak self, weak actor] in
                actor?.motion.retarget()
                if let bounds = actor?.panel.screen?.visibleFrame { self?.itemWorld.scatter(in: bounds) }
                self?.itemTarget = nil
            }
        }
        for item in CompanionItem.allCases {
            let desktopItem = DesktopItem(item: item)
            desktopItem.view.onSeek = { [weak self] in self?.seekItem(item) }
            desktopItem.view.onMove = { [weak self] point in
                guard let self, let bounds = self.actors.first?.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
                self.itemWorld.move(item, to: point, bounds: bounds)
            }
            desktopItems[item] = desktopItem
        }
        state.onScatterItems = { [weak self] in self?.scatterItems() }
        state.onSeekItem = { [weak self] item in self?.seekItem(item) }
        state.onDropItem = { [weak self] in self?.dropItem() }
        resetPositions()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in self?.resetPositions() }
        timer = Timer(timeInterval: DesktopActivity.updateInterval, repeats: true) { [weak self] _ in self?.tick() }
        timer?.tolerance = 0.002
        RunLoop.main.add(timer!, forMode: .common)
    }
    deinit {
        timer?.invalidate()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
    func resetPositions() {
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
        itemWorld.configure(enabled: state.enabledItems, bounds: visible)
        // Keep existing choices but return off-screen props after a display change.
        for (item, point) in itemWorld.ground { itemWorld.move(item, to: point, bounds: visible) }
        itemTarget = nil
    }
    func seekItem(_ item: CompanionItem) {
        guard itemWorld.ground[item] != nil else { return }
        state.roaming = true; state.showFriends = true
        itemWorld.requested = item; itemTarget = nil
        actors.first?.performance.cancel(now: Date())
        actors.first?.motion.retarget()
        state.itemStatus = "\(item.name) 주우러 가는 중"
    }
    func scatterItems() {
        guard let bounds = actors.first?.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
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
    private func publishEquipment() {
        if state.equippedItem != itemWorld.equipped { state.equippedItem = itemWorld.equipped }
    }
    func tick() {
        let now = Date(), dt = min(now.timeIntervalSince(lastTick), 0.06)
        lastTick = now
        let time = now.timeIntervalSince(started), mouse = NSEvent.mouseLocation
        if let bounds = actors.first?.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            let previous = itemWorld.equipped
            itemWorld.configure(enabled: state.enabledItems, bounds: bounds)
            if previous != itemWorld.equipped { actors.first?.performance.cancel(now: now) }
            publishEquipment()
        }
        for actor in actors {
            let enabled = state.showFriends && (state.assignments.first { $0.friend == actor.friend }?.enabled ?? false)
            guard enabled else {
                actor.panel.orderOut(nil); actor.dismissBubble()
                actor.performance.cancel(now: now)
                for item in desktopItems.values { item.update(position: nil, visible: false, mouse: mouse) }
                continue
            }
            if !actor.panel.isVisible { actor.panel.orderFrontRegardless() }
            let hovered = actor.panel.occlusionState.contains(.visible)
                && DesktopGeometry.hit(mouse, in: actor.panel.frame)
            actor.panel.ignoresMouseEvents = !hovered && !actor.view.isDragging
            let activity = DesktopActivity.resolve(roaming: state.roaming, hovered: hovered,
                                                   dragging: actor.view.isDragging,
                                                   notificationUntil: actor.bubbleUntil, now: now)
            if hovered && !actor.wasHovered { actor.hoverStarted = now }
            actor.wasHovered = hovered
            if activity != .walking || !state.expressive { actor.performance.cancel(now: now) }
            if activity == .walking, state.expressive, let item = itemWorld.equipped,
               now >= actor.performance.nextPerformance {
                actor.performance.begin(item, now: now, pickingUp: false)
            }
            var action = state.expressive ? actor.performance.action(now: now) : nil
            if activity == .walking && action == nil, let screen = actor.panel.screen ?? NSScreen.main {
                let frame = actor.panel.frame
                let draggedItems = Set(desktopItems.filter { $0.value.view.isDragging }.map(\.key))
                let targetItem = itemWorld.target(from: frame.origin, automatic: state.automaticItems,
                                                 now: now, excluding: draggedItems)
                if itemTarget != targetItem { actor.motion.retarget(); itemTarget = targetItem }
                if let targetItem, let point = itemWorld.ground[targetItem] {
                    actor.motion.destination = ItemWorld.destination(for: point)
                    if itemWorld.pickUp(targetItem, from: frame.origin, bounds: screen.visibleFrame, now: now) {
                        actor.motion.retarget(); itemTarget = nil
                        if state.expressive {
                            actor.performance.begin(targetItem, now: now, pickingUp: true)
                            action = actor.performance.action(now: now)
                        }
                        state.itemStatus = "\(targetItem.name)\(targetItem == .bag ? "을" : "를") 주웠어요"
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
                    let position = actor.motion.advance(from: frame.origin, dt: dt, bounds: screen.visibleFrame, size: frame.size)
                    actor.panel.setFrameOrigin(position)
                }
                // AppKit can round or constrain the requested position. Animate only the
                // displacement actually shown on screen, including its diagonal component.
                actor.gait.recordMovement(from: frame.origin, to: actor.panel.frame.origin)
            } else { actor.motion.stop() }
            actor.view.time = time + actor.phase
            actor.view.walking = actor.motion.isWalking
            actor.view.facing = actor.motion.facing
            actor.view.walkPhase = actor.gait.phase
            actor.view.pose = HachiwarePose.forVelocity(actor.motion.velocity)
            actor.view.happy = activity.reacts
            if state.expressive && activity == .hovering {
                action = now.timeIntervalSince(actor.hoverStarted) < 0.3 ? .wave : .laugh
            } else if state.expressive && activity == .notifying {
                action = .surprised
            }
            actor.view.action = action
            actor.view.equipped = itemWorld.equipped
            actor.view.looking = min(1, max(-1, (mouse.x - actor.panel.frame.midX) / 160))
            actor.view.needsDisplay = true
            if now < actor.bubbleUntil { actor.positionBubble() }
            else if actor.bubble != nil { actor.dismissBubble() }
            for (item, desktopItem) in desktopItems {
                desktopItem.update(position: itemWorld.ground[item], visible: enabled, mouse: mouse)
            }
        }
    }
    func notify(_ friend: Friend, sender: String, body: String? = nil, demo: Bool = false) {
        guard let actor = actors.first(where: { $0.friend == friend }) else { return }
        guard state.showFriends, state.activeAssignments.contains(where: { $0.friend == friend && $0.enabled }) else { return }
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
