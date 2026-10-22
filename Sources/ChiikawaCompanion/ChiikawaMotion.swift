import AppKit

enum ChiikawaMotion: String, CaseIterable {
    case eat, hug, pajamas, rest, blink
    var count: Int { self == .rest ? 16 : self == .blink ? 6 : 12 }
    var columns: Int { self == .blink ? 3 : 4 }
}

/// Approved pixels are registered offline; runtime only selects chronological cells.
final class ChiikawaMotionSprites {
    static let shared = ChiikawaMotionSprites()
    static let wakeDuration: TimeInterval = 0.96
    private(set) var frames: [ChiikawaMotion: [NSImage]] = [:]
    var isReady: Bool { ChiikawaMotion.allCases.allSatisfy { frames[$0]?.count == $0.count } }
    private init() {
        for motion in ChiikawaMotion.allCases {
            guard let url = HachiwareSprites.assetURL(named: "chiikawa-\(motion.rawValue)-motion-v30"),
                  let data = try? Data(contentsOf: url), let atlas = NSBitmapImageRep(data: data)?.decodedArtwork,
                  atlas.width == motion.columns*256, atlas.height == (motion.count+motion.columns-1)/motion.columns*256 else { continue }
            frames[motion] = (0..<motion.count).compactMap { index in
                atlas.cropping(to: CGRect(x: index%motion.columns*256, y: index/motion.columns*256, width: 256, height: 256))
                    .map { NSImage(cgImage: $0, size: NSSize(width: 256, height: 256)) }
            }
        }
    }
    static func index(_ motion: ChiikawaMotion, elapsed: TimeInterval) -> Int {
        let time = elapsed.isFinite ? max(0, elapsed) : 0
        switch motion {
        case .eat: return min(11, Int(time.truncatingRemainder(dividingBy: 1.8)/1.8*12))
        case .pajamas: return Int(min(11, time/1.8*12))
        case .hug:
            if time < 1.2 { return min(5, Int(time/1.2*6)) }
            return 6+min(5, Int((time-1.2).truncatingRemainder(dividingBy: 1.8)/1.8*6))
        case .rest: return Int(min(15, time/0.12))
        case .blink: return Int(min(5, time/0.045))
        }
    }
    @discardableResult
    func draw(_ motion: ChiikawaMotion, index: Int, in rect: NSRect, fraction: CGFloat = 1) -> Bool {
        guard let sequence = frames[motion], sequence.indices.contains(index) else { return false }
        let side = min(rect.width, rect.height)
        let destination = motion == .rest ? rect : NSRect(x: rect.midX-side/2, y: rect.minY, width: side, height: side)
        sequence[index].draw(in: destination,
                             from: .zero, operation: .sourceOver, fraction: fraction)
        return true
    }
    @discardableResult
    func draw(_ motion: ChiikawaMotion, in rect: NSRect, elapsed: TimeInterval) -> Bool {
        draw(motion, index: Self.index(motion, elapsed: elapsed), in: rect)
    }
}
