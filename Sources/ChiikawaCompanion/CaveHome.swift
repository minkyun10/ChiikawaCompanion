import AppKit

enum HomePhase { case outside, returning, entering, sleeping }

/// Time and arrival govern rest; the character never teleports to the house.
struct HomeRoutine {
    static let entryDuration: TimeInterval = 0.85
    static let sleepDuration: TimeInterval = 20
    static let returnInterval: TimeInterval = 90
    private(set) var phase = HomePhase.outside
    private(set) var phaseStarted: Date
    private(set) var nextReturn: Date
    private(set) var entryAllowedAfter = Date.distantPast
    var isInside: Bool { phase == .entering || phase == .sleeping }
    init(now: Date = Date()) {
        phaseStarted = now; nextReturn = now.addingTimeInterval(Self.returnInterval)
    }
    mutating func request(now: Date) {
        guard !isInside else { return }
        phase = .returning; phaseStarted = now; entryAllowedAfter = .distantPast
    }
    @discardableResult
    mutating func arrive(contact: NSPoint, entrance: NSPoint, now: Date) -> Bool {
        guard !isInside, now >= entryAllowedAfter,
              hypot(contact.x - entrance.x, contact.y - entrance.y) <= 24 else { return false }
        phase = .entering; phaseStarted = now
        return true
    }
    mutating func advance(now: Date) {
        if phase == .entering && now.timeIntervalSince(phaseStarted) >= Self.entryDuration {
            phase = .sleeping; phaseStarted = now
        }
    }
    var status: String {
        switch phase {
        case .outside: return "집을 클릭하면 쉬러 가요"
        case .returning: return "집으로 걸어가는 중"
        case .entering: return "이불 속으로 쏙…"
        case .sleeping: return "새근새근… 집을 클릭하면 일어나요"
        }
    }
    func shouldReturn(now: Date, automatic: Bool, roaming: Bool) -> Bool {
        phase == .outside && automatic && roaming && now >= nextReturn
    }
    func shouldWake(now: Date) -> Bool {
        phase == .sleeping && now.timeIntervalSince(phaseStarted) >= Self.sleepDuration
    }
    mutating func wake(now: Date) {
        phase = .outside; phaseStarted = now
        entryAllowedAfter = now.addingTimeInterval(10)
        nextReturn = now.addingTimeInterval(Self.returnInterval)
    }
}

enum HomeGeometry {
    static let size = NSSize(width: 360, height: 214)
    static func frame(in visible: NSRect) -> NSRect {
        let scale = min(1, min(visible.width / size.width, visible.height / size.height))
        let fitted = NSSize(width: size.width * scale, height: size.height * scale)
        let origin = DesktopGeometry.clamp(NSPoint(x: visible.midX - fitted.width / 2, y: visible.minY + 12),
                                           size: fitted, to: visible)
        return NSRect(origin: origin, size: fitted)
    }
    static func entrance(in frame: NSRect) -> NSPoint {
        NSPoint(x: frame.midX, y: frame.minY + frame.height * 0.16)
    }
    static func hit(_ point: NSPoint, in frame: NSRect) -> Bool {
        NSRect(x: frame.minX + frame.width * 0.22, y: frame.minY + frame.height * 0.06,
               width: frame.width * 0.56, height: frame.height * 0.68).contains(point)
    }
}

final class HomeArtwork {
    static let shared = HomeArtwork()
    let cave: NSImage?
    let sleeper: NSImage?
    var isReady: Bool { cave != nil && sleeper != nil }
    private init() {
        cave = Self.load("hachiware-cave-v11")
        sleeper = Self.load("hachiware-sleep-v11")
    }
    private static func load(_ name: String) -> NSImage? {
        guard let url = HachiwareSprites.assetURL(named: name), let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data), let image = rep.cgImage else { return nil }
        // Register generated sprites by their visible alpha bounds; retain all original pixels on disk.
        var left = image.width, top = image.height, right = 0, bottom = 0
        for y in 0..<image.height {
            for x in 0..<image.width where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.15 {
                left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y)
            }
        }
        guard right > left, bottom > top,
              let crop = image.cropping(to: CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)) else { return nil }
        return NSImage(cgImage: crop, size: NSSize(width: crop.width, height: crop.height))
    }
    static func fitted(_ size: NSSize, in rect: NSRect) -> NSRect {
        let scale = min(rect.width / size.width, rect.height / size.height)
        let result = NSSize(width: size.width * scale, height: size.height * scale)
        return NSRect(x: rect.midX - result.width / 2, y: rect.minY, width: result.width, height: result.height)
    }
    static func breathingScale(time: Double) -> CGFloat { 1 + CGFloat(sin(time * 2 * .pi / 3.6)) * 0.018 }

    func draw(in rect: NSRect, phase: HomePhase, elapsed: TimeInterval, time: Double) {
        guard let cave, let sleeper else { return }
        NSGraphicsContext.current?.imageInterpolation = .high
        cave.draw(in: Self.fitted(cave.size, in: rect.insetBy(dx: 4, dy: 4)))
        let entry = min(1, max(0, elapsed / HomeRoutine.entryDuration))
        if phase == .entering {
            let length = rect.width * CGFloat(0.32 - entry * 0.07)
            let pet = NSRect(x: rect.midX - length / 2,
                             y: rect.minY + rect.height * CGFloat(0.01 + entry * 0.16),
                             width: length, height: length * 1.12)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(CGFloat(1 - max(0, entry - 0.4) / 0.6))
            FriendArtwork.draw(.hachiware, in: pet, time: time, walking: true, facing: -1,
                               walkPhase: entry * 2 * .pi, pose: .back)
            NSGraphicsContext.restoreGraphicsState()
        }
        guard phase == .sleeping || phase == .entering else { return }
        let opacity = phase == .sleeping ? 1 : max(0, (entry - 0.45) / 0.55)
        let bed = NSRect(x: rect.minX + rect.width * 0.225, y: rect.minY + rect.height * 0.105,
                         width: rect.width * 0.465, height: rect.height * 0.40)
        var sleeping = Self.fitted(sleeper.size, in: bed)
        sleeping.size.height *= Self.breathingScale(time: time)
        sleeper.draw(in: sleeping, from: .zero, operation: .sourceOver, fraction: opacity)
        for index in 0..<3 {
            let rise = (time / 3 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
            let alpha = sin(rise * .pi) * 0.8 * opacity
            ("z" as NSString).draw(at: NSPoint(x: bed.minX + bed.width * 0.15 + CGFloat(rise) * 18,
                                               y: bed.maxY - 4 + CGFloat(rise) * 31),
                withAttributes: [.font: NSFont.systemFont(ofSize: 11 + CGFloat(rise) * 5, weight: .semibold),
                                 .foregroundColor: NSColor(hex: 0xF5F0DE, alpha: alpha)])
        }
    }
}

final class HomeView: NSView {
    var routine = HomeRoutine()
    var time = 0.0
    var now = Date()
    var onActivate: (() -> Void)?
    init() {
        super.init(frame: NSRect(origin: .zero, size: HomeGeometry.size))
        setAccessibilityElement(true); setAccessibilityRole(.button)
        setAccessibilityLabel("하치와레 집 — 클릭하면 집에 가서 자요. 자는 동안 클릭하면 깨워요.")
        toolTip = "하치와레 집 · 클릭해 쉬러 가기 · 자는 동안 클릭해 깨우기"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onActivate?(); return true }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) { onActivate?() }
    override func draw(_ dirtyRect: NSRect) {
        HomeArtwork.shared.draw(in: bounds, phase: routine.phase,
                                elapsed: now.timeIntervalSince(routine.phaseStarted), time: time)
    }
}

final class DesktopHome {
    let panel: FriendPanel
    let view = HomeView()
    private var screenNumber: NSNumber?
    init() {
        _ = HomeArtwork.shared
        panel = FriendPanel(contentRect: view.bounds, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = view; panel.title = "하치와레 집"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.isFloatingPanel = false; panel.level = DesktopLayer.character
        panel.collectionBehavior = DesktopLayer.collection; panel.animationBehavior = .none
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false; panel.ignoresMouseEvents = true
        anchorToScreen()
    }
    func anchorToScreen() {
        let screen = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == screenNumber }
            ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        panel.setFrame(HomeGeometry.frame(in: screen.visibleFrame), display: false)
    }
    var entrance: NSPoint { HomeGeometry.entrance(in: panel.frame) }
    func update(visible: Bool, mouse: NSPoint, routine: HomeRoutine, now: Date, time: Double) {
        guard visible else { panel.orderOut(nil); return }
        if !panel.isVisible { panel.orderFrontRegardless() }
        panel.ignoresMouseEvents = !(panel.occlusionState.contains(.visible) && HomeGeometry.hit(mouse, in: panel.frame))
        let changed = view.routine.phase != routine.phase
        view.routine = routine; view.now = now; view.time = time
        if changed || routine.isInside { view.needsDisplay = true }
    }
}
