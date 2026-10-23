import Foundation

/// A bounded, monotonic click window. Dragging and other characters break the
/// sequence. Monster form has one fixed deadline; clicks cannot extend it.
struct HachiwareTransformation {
    static let requiredClicks = 5
    static let clickWindow: TimeInterval = 10
    static let transitionDuration: TimeInterval = 0.65
    static let monsterDuration: TimeInterval = 30
    private(set) var isMonster = false
    private(set) var clicks: [TimeInterval] = []
    private(set) var changedAt: TimeInterval?
    private(set) var returnsAt: TimeInterval?
    private(set) var transitionFromMonster = 0.0

    mutating func interruptSequence() { clicks.removeAll(keepingCapacity: true) }

    @discardableResult
    mutating func click(at time: TimeInterval) -> Bool {
        guard time.isFinite else { interruptSequence(); return false }
        guard !isMonster else { return false }
        if let last = clicks.last, time < last { interruptSequence() }
        clicks.removeAll { time - $0 > Self.clickWindow }
        clicks.append(time)
        guard clicks.count == Self.requiredClicks else { return false }
        interruptSequence()
        transitionFromMonster = monsterOpacity(at:time)
        isMonster = true; changedAt = time
        returnsAt = time + Self.monsterDuration
        return true
    }

    /// Use the next actual update as the fade origin after a delayed tick, so
    /// resuming the app never skips straight from the monster to normal artwork.
    @discardableResult
    mutating func advance(at time: TimeInterval) -> Bool {
        guard time.isFinite, isMonster, let returnsAt, time >= returnsAt else { return false }
        transitionFromMonster = monsterOpacity(at:time)
        isMonster = false; changedAt = time; self.returnsAt = nil
        interruptSequence()
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
