import AppKit

/// House skins never own geometry or character membership.
enum HomeStyle: String, CaseIterable, Identifiable {
    case hachiware, chiikawa
    var id: String { rawValue }
    var title: String { self == .hachiware ? "하치와레 집" : "치이카와 집" }
}

struct HomeOccupant {
    let friend: Friend
    let routine: HomeRoutine
}

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
    let chiikawaHouse: NSImage?
    let sleeper: NSImage?
    var isReady: Bool { cave != nil && chiikawaHouse != nil && sleeper != nil }
    private init() {
        cave = Self.load("hachiware-cave-v11")
        chiikawaHouse = Self.load("chiikawa-house-v26")
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
        let now = Date(timeIntervalSince1970: 1000)
        var routine = HomeRoutine(now: now)
        if phase == .entering || phase == .sleeping {
            routine.request(now: now)
            _ = routine.arrive(contact: .zero, entrance: .zero, now: now)
            if phase == .sleeping { routine.advance(now: now.addingTimeInterval(HomeRoutine.entryDuration)) }
        }
        draw(in: rect, style: .hachiware, occupants: [HomeOccupant(friend: .hachiware, routine: routine)],
             now: routine.phaseStarted.addingTimeInterval(elapsed), time: time)
    }

    func draw(in rect: NSRect, style: HomeStyle, occupants: [HomeOccupant], now: Date, time: Double) {
        guard let background = style == .chiikawa ? chiikawaHouse ?? cave : cave else { return }
        NSGraphicsContext.current?.imageInterpolation = .high
        // Preserve each original design's proportions inside the one fixed house window.
        background.draw(in: Self.fitted(background.size, in: rect.insetBy(dx: 4, dy: 4)))
        let inside = occupants.filter { $0.routine.isInside }
        for (index, occupant) in inside.enumerated() {
            drawOccupant(occupant, index: index, count: inside.count, in: rect, now: now, time: time)
        }
    }

    private func drawOccupant(_ occupant: HomeOccupant, index: Int, count: Int, in rect: NSRect, now: Date, time: Double) {
        let phase = occupant.routine.phase
        let elapsed = max(0, now.timeIntervalSince(occupant.routine.phaseStarted))
        let entry = min(1, max(0, elapsed / HomeRoutine.entryDuration))
        if phase == .entering {
            let length = rect.width * CGFloat(0.32 - entry * 0.07)
            let pet = NSRect(x: rect.midX - length / 2,
                             y: rect.minY + rect.height * CGFloat(0.01 + entry * 0.16),
                             width: length, height: length * 1.12)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(CGFloat(1 - max(0, entry - 0.4) / 0.6))
            if occupant.friend == .chiikawa, let pajamas = ChiikawaLifeSprites.shared.pajamas {
                pajamas.draw(in: Self.fitted(pajamas.size, in: pet))
            } else {
                FriendArtwork.draw(occupant.friend, in: pet, time: time, walking: true, facing: -1,
                                   walkPhase: entry * 2 * .pi, pose: .back)
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        guard phase == .sleeping || phase == .entering else { return }
        let opacity = phase == .sleeping ? 1 : max(0, (entry - 0.45) / 0.55)
        guard let sleeper = occupant.friend == .chiikawa ? ChiikawaLifeSprites.shared.sleeper : sleeper else { return }
        let columns = max(1, Int(ceil(sqrt(Double(count)))))
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let area = NSRect(x: rect.minX + rect.width * 0.225, y: rect.minY + rect.height * 0.105,
                          width: rect.width * (count == 1 ? 0.465 : 0.55), height: rect.height * 0.40)
        let bed = NSRect(x: area.minX + CGFloat(index % columns) * area.width / CGFloat(columns),
                         y: area.minY + CGFloat(index / columns) * area.height / CGFloat(rows),
                         width: area.width / CGFloat(columns), height: area.height / CGFloat(rows))
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
    var style = HomeStyle.hachiware
    var occupants: [HomeOccupant] = []
    var time = 0.0
    var now = Date()
    var onActivate: (() -> Void)?
    init() {
        super.init(frame: NSRect(origin: .zero, size: HomeGeometry.size))
        setAccessibilityElement(true); setAccessibilityRole(.button)
        updateDescription()
    }
    func updateDescription() {
        let names = occupants.filter { $0.routine.isInside }.map { $0.friend.name }.joined(separator: ", ")
        let action = names.isEmpty ? "클릭하면 보이는 친구들이 함께 쉬러 가요" : "\(names) 자는 중 · 클릭하면 깨워요"
        setAccessibilityLabel("공용 집 · \(style.title) — \(action)")
        toolTip = "공용 집 · \(style.title) · \(action)"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onActivate?(); return true }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) { onActivate?() }
    override func draw(_ dirtyRect: NSRect) {
        HomeArtwork.shared.draw(in: bounds, style: style, occupants: occupants, now: now, time: time)
    }
}

final class DesktopHome {
    let panel: FriendPanel
    let view = HomeView()
    private var screenNumber: NSNumber?
    init() {
        _ = HomeArtwork.shared
        panel = FriendPanel(contentRect: view.bounds, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = view; panel.title = "공용 집"
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
    func update(visible: Bool, mouse: NSPoint, style: HomeStyle, occupants: [HomeOccupant], now: Date, time: Double) {
        guard visible else { panel.orderOut(nil); return }
        if !panel.isVisible { panel.orderFrontRegardless() }
        panel.ignoresMouseEvents = !(panel.occlusionState.contains(.visible) && HomeGeometry.hit(mouse, in: panel.frame))
        let changed = view.style != style || view.occupants.map(\.friend) != occupants.map(\.friend)
            || view.occupants.map(\.routine.phase) != occupants.map(\.routine.phase)
        view.style = style; view.occupants = occupants; view.now = now; view.time = time
        if changed { view.updateDescription() }
        if changed || occupants.contains(where: { $0.routine.isInside }) { view.needsDisplay = true }
    }
}
