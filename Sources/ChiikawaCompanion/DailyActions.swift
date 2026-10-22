import AppKit

/// Registered, transparent animation frames, isolated from the approved walking sheets.
final class DailyActionSprites {
    static let shared = DailyActionSprites()
    static let frameCount = 12
    static let assetNames: [HachiwareAction: String] = [
        .study: "hachiware-study-v16", .eat: "hachiware-eat-v16", .vomit: "hachiware-vomit-v16"
    ]
    private(set) var frames: [HachiwareAction: [NSImage]] = [:]
    var isReady: Bool {
        HachiwareAction.daily.allSatisfy { frames[$0]?.count == Self.frameCount }
    }
    private init() {
        for action in HachiwareAction.daily {
            guard let name = Self.assetNames[action], let url = HachiwareSprites.assetURL(named: name),
                  let data = try? Data(contentsOf: url), let atlas = NSBitmapImageRep(data: data)?.decodedArtwork,
                  atlas.width == 1536, atlas.height == 512 else { continue }
            var cells: [NSImage] = []
            for index in 0..<Self.frameCount {
                guard let image = atlas.cropping(to: CGRect(x: index % 6 * 256, y: index / 6 * 256,
                                                          width: 256, height: 256)) else { break }
                cells.append(NSImage(cgImage: image, size: NSSize(width: 256, height: 256)))
            }
            frames[action] = cells
        }
    }
    static func frameIndex(_ action: HachiwareAction, time: TimeInterval) -> Int {
        guard time.isFinite, time > 0 else { return 0 }
        let progress = time.truncatingRemainder(dividingBy: action.cycleDuration) / action.cycleDuration
        return min(frameCount - 1, Int(floor(progress * Double(frameCount))))
    }
    @discardableResult
    func draw(_ action: HachiwareAction, in rect: NSRect, time: Double) -> Bool {
        guard let frames = frames[action], frames.count == Self.frameCount else { return false }
        let length = min(rect.width, rect.height)
        frames[Self.frameIndex(action, time: time)].draw(in: NSRect(x: rect.midX - length / 2,
            y: rect.midY - length / 2, width: length, height: length))
        return true
    }
}
