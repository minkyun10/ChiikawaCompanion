import Foundation

/// A bounded, monotonic click window. Dragging and other characters break the
/// sequence; completing a window consumes every click, so click six is not a toggle.
struct HachiwareTransformation {
    static let requiredClicks = 5
    static let clickWindow: TimeInterval = 10
    static let transitionDuration: TimeInterval = 0.65
    private(set) var isMonster = false
    private(set) var clicks: [TimeInterval] = []
    private(set) var changedAt: TimeInterval?
    private(set) var transitionFromMonster = 0.0

    mutating func interruptSequence() { clicks.removeAll(keepingCapacity: true) }

    @discardableResult
    mutating func click(at time: TimeInterval) -> Bool {
        guard time.isFinite else { interruptSequence(); return false }
        if let last = clicks.last, time < last { interruptSequence() }
        clicks.removeAll { time - $0 > Self.clickWindow }
        clicks.append(time)
        guard clicks.count == Self.requiredClicks else { return false }
        interruptSequence()
        transitionFromMonster = monsterOpacity(at:time)
        isMonster.toggle(); changedAt = time
        return true
    }

    func progress(at time: TimeInterval) -> Double {
        guard let changedAt else { return 1 }
        return min(1, max(0, (time - changedAt) / Self.transitionDuration))
    }
    func monsterOpacity(at time: TimeInterval) -> Double {
        let target = isMonster ? 1.0:0.0
        return transitionFromMonster+(target-transitionFromMonster)*progress(at:time)
    }
}
