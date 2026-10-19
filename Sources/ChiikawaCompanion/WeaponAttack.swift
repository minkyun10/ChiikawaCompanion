import AppKit

/// A dedicated attack atlas includes the weapon and expression; no second prop is drawn over it.
final class WeaponAttackSprites {
    static let shared = WeaponAttackSprites()
    static let assetName = "hachiware-attack-v19"
    static let frameCount = 12
    static let cycleDuration: TimeInterval = 1.2
    private(set) var frames: [NSImage] = []
    var isReady: Bool { frames.count == Self.frameCount }

    private init() {
        guard let url = HachiwareSprites.assetURL(named: Self.assetName), let data = try? Data(contentsOf: url),
              let atlas = NSBitmapImageRep(data: data)?.cgImage, atlas.width == 1536, atlas.height == 512 else { return }
        for index in 0..<Self.frameCount {
            guard let frame = atlas.cropping(to: CGRect(x: index % 6 * 256, y: index / 6 * 256, width: 256, height: 256)) else { return }
            frames.append(NSImage(cgImage: frame, size: NSSize(width: 256, height: 256)))
        }
    }
    static func frameIndex(time: TimeInterval) -> Int {
        guard time.isFinite && time > 0 else { return 0 }
        return min(frameCount-1, Int(floor(time.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration * Double(frameCount))))
    }
    @discardableResult
    func draw(in rect: NSRect, time: TimeInterval) -> Bool {
        guard isReady else { return false }
        let length = min(rect.width, rect.height)
        frames[Self.frameIndex(time: time)].draw(in: NSRect(x: rect.midX-length/2,y: rect.midY-length/2,width: length,height: length))
        return true
    }
}
