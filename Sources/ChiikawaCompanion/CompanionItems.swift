import AppKit

enum CompanionItem: String, CaseIterable, Codable, Identifiable {
    case camera, guitar, sasumata, bag
    var id: String { rawValue }
    var name: String {
        switch self {
        case .camera: return "카메라"
        case .guitar: return "기타"
        case .sasumata: return "파란 사스마타"
        case .bag: return "산책 가방"
        }
    }
    var symbol: String {
        switch self {
        case .camera: return "camera"
        case .guitar: return "guitars"
        case .sasumata: return "sparkles"
        case .bag: return "bag"
        }
    }
    var detail: String {
        switch self {
        case .camera: return "목에 걸고, 찰칵!"
        case .guitar: return "산책하다 잠깐 연주해요"
        case .sasumata: return "토벌 도구를 들고 씩씩하게"
        case .bag: return "팬메이드 산책 소품"
        }
    }
    var action: HachiwareAction {
        switch self {
        case .camera: return .camera
        case .guitar: return .guitar
        case .sasumata: return .sasumata
        case .bag: return .bag
        }
    }
}

/// One instance of each enabled item: either on the ground or being carried.
/// This model contains no notification or sender information.
struct ItemWorld {
    private(set) var ground: [CompanionItem: NSPoint] = [:]
    private(set) var equipped: CompanionItem?
    private(set) var enabled = Set<CompanionItem>()
    private(set) var availableAfter: [CompanionItem: Date] = [:]
    private(set) var nextAutomaticPickup = Date.distantPast
    var requested: CompanionItem?

    static let contactOffset = NSPoint(x: 66, y: 30)
    static func contactPoint(origin: NSPoint) -> NSPoint {
        NSPoint(x: origin.x + contactOffset.x, y: origin.y + contactOffset.y)
    }
    static func destination(for point: NSPoint) -> NSPoint {
        NSPoint(x: point.x - contactOffset.x, y: point.y - contactOffset.y)
    }
    static func clamp(_ point: NSPoint, to bounds: NSRect) -> NSPoint {
        let origin = DesktopGeometry.clamp(destination(for: point), size: NSSize(width: 132, height: 150), to: bounds)
        return contactPoint(origin: origin)
    }
    mutating func configure(enabled newValue: Set<CompanionItem>, bounds: NSRect) {
        for item in enabled.subtracting(newValue) {
            ground[item] = nil; availableAfter[item] = nil
            if equipped == item { equipped = nil }
            if requested == item { requested = nil }
        }
        let added = newValue.subtracting(enabled)
        enabled = newValue
        for item in added { ground[item] = spawn(item, bounds: bounds) }
    }
    private func spawn(_ item: CompanionItem, bounds: NSRect) -> NSPoint {
        let fractions: [(CGFloat, CGFloat)] = [(0.30, 0.30), (0.74, 0.60), (0.42, 0.82), (0.82, 0.20)]
        let f = fractions[CompanionItem.allCases.firstIndex(of: item)!]
        return Self.contactPoint(origin: RoamingMotion.target(in: bounds,
            size: NSSize(width: 132, height: 150), xFraction: f.0, yFraction: f.1))
    }
    mutating func scatter(in bounds: NSRect) {
        for item in enabled where item != equipped {
            ground[item] = Self.contactPoint(origin: RoamingMotion.target(in: bounds,
                size: NSSize(width: 132, height: 150), xFraction: .random(in: 0.10...0.90),
                yFraction: .random(in: 0.12...0.85)))
        }
        requested = nil
    }
    mutating func move(_ item: CompanionItem, to point: NSPoint, bounds: NSRect) {
        guard ground[item] != nil else { return }
        ground[item] = Self.clamp(point, to: bounds)
    }
    func target(from origin: NSPoint, automatic: Bool, now: Date,
                excluding dragged: Set<CompanionItem> = []) -> CompanionItem? {
        if let requested, ground[requested] != nil { return dragged.contains(requested) ? nil : requested }
        guard automatic, now >= nextAutomaticPickup else { return nil }
        let contact = Self.contactPoint(origin: origin)
        return ground.keys.filter { !dragged.contains($0) && now >= (availableAfter[$0] ?? .distantPast) }.min {
            let a = ground[$0]!, b = ground[$1]!
            return hypot(contact.x - a.x, contact.y - a.y) < hypot(contact.x - b.x, contact.y - b.y)
        }
    }
    @discardableResult
    mutating func pickUp(_ item: CompanionItem, from origin: NSPoint, bounds: NSRect, now: Date) -> Bool {
        guard let point = ground[item], enabled.contains(item) else { return false }
        let contact = Self.contactPoint(origin: origin)
        guard hypot(contact.x - point.x, contact.y - point.y) <= 30 else { return false }
        drop(at: NSPoint(x: contact.x - 85, y: contact.y + 12), bounds: bounds, now: now)
        ground[item] = nil; availableAfter[item] = nil
        equipped = item; requested = nil
        nextAutomaticPickup = now.addingTimeInterval(24)
        return true
    }
    mutating func drop(at point: NSPoint, bounds: NSRect, now: Date) {
        guard let item = equipped else { return }
        ground[item] = Self.clamp(point, to: bounds)
        availableAfter[item] = now.addingTimeInterval(12)
        equipped = nil
        nextAutomaticPickup = now.addingTimeInterval(8)
    }
}

enum HachiwareAction: Int, CaseIterable {
    case wave, laugh, surprised, pickup, camera, guitar, sasumata, bag
    var title: String {
        ["안녕!", "헤헤", "와아!", "주워 볼까?", "찰칵!", "기타 연주", "씩씩하게", "산책 준비"][rawValue]
    }
}

/// Item actions are interruptible. A hover never leaves a timed reaction behind.
struct CompanionPerformance {
    private(set) var started = Date.distantPast
    private(set) var until = Date.distantPast
    private(set) var item: CompanionItem?
    private(set) var nextPerformance = Date.distantPast
    mutating func begin(_ item: CompanionItem, now: Date, pickingUp: Bool) {
        self.item = item; started = now
        until = now.addingTimeInterval(pickingUp ? 3.1 : 2.4)
        nextPerformance = now.addingTimeInterval(17)
    }
    mutating func cancel(now: Date) {
        item = nil; until = .distantPast
        nextPerformance = now.addingTimeInterval(12)
    }
    func action(now: Date) -> HachiwareAction? {
        guard now < until, let item else { return nil }
        return until.timeIntervalSince(started) > 3 && now.timeIntervalSince(started) < 0.65 ? .pickup : item.action
    }
}
