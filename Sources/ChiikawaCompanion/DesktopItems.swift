import AppKit

final class DesktopItemView: NSView {
    let item: CompanionItem
    var hovered = false
    var isDragging = false
    var onSeek: (() -> Void)?
    var onMove: ((NSPoint) -> Void)?
    private var down = NSPoint.zero
    private var origin = NSPoint.zero
    private var moved = false
    init(item: CompanionItem) {
        self.item = item
        super.init(frame: NSRect(x: 0, y: 0, width: 76, height: 84))
        setAccessibilityElement(true); setAccessibilityRole(.button)
        setAccessibilityLabel("\(item.name) — 클릭하면 하치와레가 주우러 와요. 드래그로 옮기기.")
        toolTip = "\(item.name) · 클릭해 주우러 오게 하기 · 드래그로 옮기기"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onSeek?(); return true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.10).setFill()
        NSBezierPath(ovalIn: NSRect(x: 17, y: 14, width: 42, height: 6)).fill()
        if hovered {
            NSColor(hex: 0xFFFDF6, alpha: 0.85).setFill()
            NSBezierPath(roundedRect: NSRect(x: 6, y: 9, width: 64, height: 66), xRadius: 16, yRadius: 16).fill()
        }
        ItemArtwork.draw(item, in: NSRect(x: 6, y: 15, width: 64, height: 64))
    }
    override func mouseDown(with event: NSEvent) {
        down = NSEvent.mouseLocation; origin = window?.frame.origin ?? .zero
        isDragging = true; moved = false
    }
    override func mouseDragged(with event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - down.x, dy = mouse.y - down.y
        if abs(dx) + abs(dy) > 4 { moved = true }
        onMove?(NSPoint(x: origin.x + dx + 38, y: origin.y + dy + 16))
    }
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if !moved { onSeek?() }
    }
}

final class DesktopItem {
    let panel: FriendPanel
    let view: DesktopItemView
    init(item: CompanionItem) {
        view = DesktopItemView(item: item)
        panel = FriendPanel(contentRect: view.bounds, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = view; panel.title = "산책 소품 · \(item.name)"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.isFloatingPanel = false; panel.level = DesktopLayer.character
        panel.collectionBehavior = DesktopLayer.collection; panel.animationBehavior = .none
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
    }
    func update(position: NSPoint?, visible: Bool, mouse: NSPoint) {
        guard visible, let position else { panel.orderOut(nil); return }
        let origin = NSPoint(x: position.x - 38, y: position.y - 16)
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }
        if !panel.isVisible { panel.orderFrontRegardless() }
        let hovered = panel.occlusionState.contains(.visible)
            && panel.frame.insetBy(dx: 10, dy: 8).contains(mouse)
        panel.ignoresMouseEvents = !hovered && !view.isDragging
        if view.hovered != hovered { view.hovered = hovered; view.needsDisplay = true }
    }
}
