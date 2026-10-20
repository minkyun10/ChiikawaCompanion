import AppKit

enum ChiikawaLifeAction: String, CaseIterable, Identifiable {
    case study, pajamas, hug
    var id: String { rawValue }
    var title: String {
        switch self { case .study: return "제초 시험 공부"; case .pajamas: return "잠옷 입기"; case .hug: return "인형 안기" }
    }
    var duration: TimeInterval { self == .study ? 9 : 5 }
}

struct ChiikawaLifeRoutine {
    private(set) var selected: ChiikawaLifeAction?
    private(set) var started = Date.distantPast
    mutating func begin(_ action: ChiikawaLifeAction, now: Date) { selected = action; started = now }
    mutating func cancel() { selected = nil }
    func action(now: Date) -> ChiikawaLifeAction? {
        guard let selected, now >= started, now.timeIntervalSince(started) < selected.duration else { return nil }
        return selected
    }
    func elapsed(now: Date) -> TimeInterval { max(0, now.timeIntervalSince(started)) }
}

/// New cutouts have their own registration. The approved walk and attack sheets stay untouched.
final class ChiikawaLifeSprites {
    static let shared = ChiikawaLifeSprites()
    let house: NSImage?
    let sleeper: NSImage?
    let pajamas: NSImage?
    let hug: NSImage?
    private(set) var studyFrames: [NSImage] = []
    var isReady: Bool { house != nil && sleeper != nil && pajamas != nil && hug != nil && studyFrames.count == 12 }
    private init() {
        house = Self.load("chiikawa-house-v26"); sleeper = Self.load("chiikawa-sleep-v26")
        pajamas = Self.load("chiikawa-pajamas-v26"); hug = Self.load("chiikawa-hug-v26")
        if let url = HachiwareSprites.assetURL(named: "chiikawa-study-v26"),
           let data = try? Data(contentsOf: url), let atlas = NSBitmapImageRep(data: data)?.cgImage,
           atlas.width == 1536, atlas.height == 512 {
            for index in 0..<12 {
                guard let image = atlas.cropping(to: CGRect(x: index % 6 * 256, y: index / 6 * 256, width: 256, height: 256)) else { break }
                studyFrames.append(NSImage(cgImage: image, size: NSSize(width: 256, height: 256)))
            }
        }
    }
    static func load(_ name: String) -> NSImage? {
        guard let url = HachiwareSprites.assetURL(named: name) else { return nil }
        return NSImage(contentsOf: url)
    }
    static func studyIndex(time: TimeInterval) -> Int {
        guard time.isFinite, time > 0 else { return 0 }
        return min(11, Int(floor(time.truncatingRemainder(dividingBy: 1.8) / 1.8 * 12)))
    }
    @discardableResult
    func draw(_ action: ChiikawaLifeAction, in rect: NSRect, elapsed: TimeInterval) -> Bool {
        NSGraphicsContext.current?.imageInterpolation = .high
        if action == .study, studyFrames.count == 12 {
            let side = min(rect.width, rect.height)
            studyFrames[Self.studyIndex(time: elapsed)].draw(in: NSRect(x: rect.midX-side/2, y: rect.midY-side/2, width: side, height: side))
            return true
        }
        guard let image = action == .pajamas ? pajamas : hug else { return false }
        let side = min(rect.width, rect.height)
        var fitted = HomeArtwork.fitted(image.size, in: NSRect(x: rect.midX-side*0.43, y: rect.minY+side*0.13, width: side*0.86, height: side*0.84))
        fitted.origin.y += CGFloat(sin(elapsed * 2.5)) * side * 0.006
        image.draw(in: fitted)
        return true
    }
}

enum ChiikawaHomeGeometry {
    static let size = NSSize(width: 340, height: 240)
    static func frame(in visible: NSRect) -> NSRect {
        let cave = HomeGeometry.frame(in: visible)
        let space = visible.maxX-cave.maxX-16
        let scale = min(1, max(0.3, space/size.width), visible.height/size.height)
        let fitted = NSSize(width: size.width*scale, height: size.height*scale)
        let origin = DesktopGeometry.clamp(NSPoint(x: cave.maxX+8, y: visible.minY+12), size: fitted, to: visible)
        return NSRect(origin: origin, size: fitted)
    }
    static func entrance(in frame: NSRect) -> NSPoint {
        NSPoint(x: frame.minX+frame.width*0.50, y: frame.minY+frame.height*0.15)
    }
    static func hit(_ point: NSPoint, in frame: NSRect) -> Bool {
        frame.insetBy(dx: frame.width*0.07, dy: frame.height*0.09).contains(point)
    }
}

final class ChiikawaHomeView: NSView {
    var routine = HomeRoutine()
    var now = Date(), time = 0.0
    var onActivate: (() -> Void)?
    init() {
        super.init(frame: NSRect(origin: .zero, size: ChiikawaHomeGeometry.size))
        setAccessibilityElement(true); setAccessibilityRole(.button)
        setAccessibilityLabel("치이카와 집 — 클릭하면 열쇠를 가지고 귀가해 잠옷을 입고 자요. 잠든 동안 클릭하면 깨워요.")
        toolTip = "치이카와 집 · 클릭해 귀가 · 자는 동안 클릭해 깨우기"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func accessibilityPerformPress() -> Bool { onActivate?(); return true }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) { onActivate?() }
    override func draw(_ dirtyRect: NSRect) {
        Self.draw(in: bounds, routine: routine, now: now, time: time)
    }
    static func draw(in rect: NSRect, routine: HomeRoutine, now: Date, time: Double) {
        let art = ChiikawaLifeSprites.shared
        guard let house = art.house else { return }
        NSGraphicsContext.current?.imageInterpolation = .high
        house.draw(in: HomeArtwork.fitted(house.size, in: rect.insetBy(dx: 4, dy: 4)))
        guard routine.isInside else { return }
        let elapsed = max(0, now.timeIntervalSince(routine.phaseStarted))
        if routine.phase == .entering {
            let progress = min(1, elapsed/HomeRoutine.entryDuration)
            let size = rect.width*0.24
            let destination = NSRect(x: rect.midX-size/2, y: rect.minY+rect.height*0.09+CGFloat(progress)*8,
                                     width: size, height: size*1.1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(1-CGFloat(progress)*0.6)
            if let pajamas = art.pajamas { pajamas.draw(in: HomeArtwork.fitted(pajamas.size, in: destination)) }
            NSGraphicsContext.restoreGraphicsState()
        } else if let sleeper = art.sleeper {
            let bed = NSRect(x: rect.minX+rect.width*0.14, y: rect.minY+rect.height*0.13,
                             width: rect.width*0.45, height: rect.height*0.42)
            var fitted = HomeArtwork.fitted(sleeper.size, in: bed)
            fitted.size.height *= HomeArtwork.breathingScale(time: time)
            sleeper.draw(in: fitted)
            for index in 0..<2 {
                let rise = (time/3+Double(index)/2).truncatingRemainder(dividingBy: 1)
                ("z" as NSString).draw(at: NSPoint(x: bed.minX+CGFloat(rise)*18, y: bed.maxY-3+CGFloat(rise)*23),
                    withAttributes: [.font: NSFont.systemFont(ofSize: 11+CGFloat(rise)*4, weight: .medium),
                                     .foregroundColor: NSColor(hex: 0xAE7C91, alpha: sin(rise * .pi)*0.8)])
            }
        }
    }
}

final class DesktopChiikawaHome {
    let panel: FriendPanel
    let view = ChiikawaHomeView()
    private var screenNumber: NSNumber?
    init() {
        panel = FriendPanel(contentRect: view.bounds, styleMask: [.borderless,.nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = view; panel.title = "치이카와 집"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.isFloatingPanel = false; panel.level = DesktopLayer.character; panel.collectionBehavior = DesktopLayer.collection
        panel.animationBehavior = .none; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true; anchorToScreen()
    }
    func anchorToScreen() {
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == screenNumber
        }) ?? NSScreen.main ?? NSScreen.screens.first else { return }
        screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        panel.setFrame(ChiikawaHomeGeometry.frame(in: screen.visibleFrame), display: false)
    }
    var entrance: NSPoint { ChiikawaHomeGeometry.entrance(in: panel.frame) }
    func update(visible: Bool, mouse: NSPoint, routine: HomeRoutine, now: Date, time: Double) {
        guard visible else { panel.orderOut(nil); return }
        if !panel.isVisible { panel.orderFrontRegardless() }
        panel.ignoresMouseEvents = !(panel.occlusionState.contains(.visible) && ChiikawaHomeGeometry.hit(mouse, in: panel.frame))
        let changed = view.routine.phase != routine.phase
        view.routine = routine; view.now = now; view.time = time
        if changed || routine.isInside { view.needsDisplay = true }
    }
}

/// These small accessories extend the existing native prop drawings.
enum ChiikawaLifeItemArtwork {
    static func drawKey(in rect: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.minY); cg.scaleBy(x: rect.width/100, y: rect.height/100)
        let ink = ChiikawaItemArtwork.ink, yellow = NSColor(hex: 0xF5D85F)
        let ring = NSBezierPath(roundedRect: NSRect(x: 23,y: 47,width: 54,height: 44),xRadius: 5,yRadius: 5)
        yellow.setFill(); ring.fill(); ink.setStroke(); ring.lineWidth = 3; ring.stroke()
        let hole = NSBezierPath(roundedRect: NSRect(x: 40,y: 61,width: 20,height: 16),xRadius: 2,yRadius: 2)
        NSColor(hex: 0xFFF9EA).setFill(); hole.fill(); ink.setStroke(); hole.lineWidth = 2; hole.stroke()
        let stem = NSBezierPath(); stem.move(to: NSPoint(x: 43,y: 47)); stem.line(to: NSPoint(x: 43,y: 12))
        stem.line(to: NSPoint(x: 66,y: 12)); stem.line(to: NSPoint(x: 66,y: 23)); stem.line(to: NSPoint(x: 56,y: 23))
        stem.line(to: NSPoint(x: 56,y: 31)); stem.line(to: NSPoint(x: 68,y: 31)); stem.line(to: NSPoint(x: 68,y: 41))
        stem.line(to: NSPoint(x: 56,y: 41)); stem.line(to: NSPoint(x: 56,y: 47)); stem.close()
        yellow.setFill(); stem.fill(); ink.setStroke(); stem.lineWidth = 3; stem.lineJoinStyle = .round; stem.stroke()
        cg.restoreGState()
    }
    static func drawToy(in rect: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.minY); cg.scaleBy(x: rect.width/100, y: rect.height/100)
        let brown = NSColor(hex: 0xB67945)
        ChiikawaItemArtwork.oval(NSRect(x: 21,y: 12,width: 58,height: 72),color: brown,line: 3)
        for point in [NSPoint(x: 21,y: 73),NSPoint(x: 68,y: 73),NSPoint(x: 14,y: 33),NSPoint(x: 72,y: 33)] {
            ChiikawaItemArtwork.oval(NSRect(x: point.x,y: point.y,width: 15,height: 18),color: brown,line: 2)
        }
        ChiikawaItemArtwork.oval(NSRect(x: 34,y: 54,width: 6,height: 7),color: .white,line: 1)
        ChiikawaItemArtwork.oval(NSRect(x: 60,y: 54,width: 6,height: 7),color: .white,line: 1)
        let mouth = NSBezierPath(roundedRect: NSRect(x: 35,y: 25,width: 30,height: 22),xRadius: 7,yRadius: 7)
        ChiikawaItemArtwork.ink.setFill(); mouth.fill()
        for x in [39,49,59] {
            let tooth = NSBezierPath(); tooth.move(to: NSPoint(x: x,y: 45)); tooth.line(to: NSPoint(x: x+5,y: 45)); tooth.line(to: NSPoint(x: x+2,y: 38)); tooth.close()
            NSColor.white.setFill(); tooth.fill()
        }
        cg.restoreGState()
    }
    static func drawDesk(in rect: NSRect) {
        let ink = ChiikawaItemArtwork.ink
        let top = NSRect(x: rect.minX+rect.width*0.10,y: rect.minY+rect.height*0.25,width: rect.width*0.80,height: rect.height*0.35)
        for fraction: CGFloat in [0.24,0.68] {
            let leg = NSBezierPath(roundedRect: NSRect(x: rect.minX+rect.width*fraction,y: rect.minY+rect.height*0.15,width: rect.width*0.10,height: rect.height*0.22),xRadius: 4,yRadius: 4)
            ChiikawaItemArtwork.pink.setFill(); leg.fill(); ink.setStroke(); leg.lineWidth = 2; leg.stroke()
        }
        let table = NSBezierPath(ovalIn: top); ChiikawaItemArtwork.pink.setFill(); table.fill(); ink.setStroke(); table.lineWidth = 2.5; table.stroke()
        let book = NSBezierPath(roundedRect: NSRect(x: rect.midX-rect.width*0.23,y: top.midY,width: rect.width*0.46,height: rect.height*0.25),xRadius: 3,yRadius: 3)
        NSColor(hex: 0xFFFDF3).setFill(); book.fill(); ink.setStroke(); book.lineWidth = 1.5; book.stroke()
        ChiikawaItemArtwork.stroke([NSPoint(x: rect.midX,y: top.midY),NSPoint(x: rect.midX,y: top.midY+rect.height*0.25)],width: 1,color: ink)
        for fraction: CGFloat in [0.06,0.12,0.18] {
            ChiikawaItemArtwork.stroke([NSPoint(x: rect.midX+5,y: top.midY+rect.height*fraction),NSPoint(x: rect.midX+rect.width*0.18,y: top.midY+rect.height*fraction)],width: 1,color: ink)
        }
    }
}
