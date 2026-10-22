import AppKit

/// A dedicated attack atlas includes the weapon and expression; no second prop is drawn over it.
final class WeaponAttackSprites {
    static let shared = WeaponAttackSprites()
    static let assetName = "hachiware-attack-v19"
    static let frameCount = 12
    static let cycleDuration: TimeInterval = 1.2
    private(set) var frames: [NSImage] = []
    private(set) var registration: AttackRegistration?
    var isReady: Bool { frames.count == Self.frameCount && registration != nil }

    private init() {
        guard let url = HachiwareSprites.assetURL(named: Self.assetName), let data = try? Data(contentsOf: url),
              let atlas = NSBitmapImageRep(data: data)?.decodedArtwork, atlas.width == 1536, atlas.height == 512 else { return }
        for index in 0..<Self.frameCount {
            guard let frame = atlas.cropping(to: CGRect(x: index % 6 * 256, y: index / 6 * 256, width: 256, height: 256)) else { return }
            frames.append(NSImage(cgImage: frame, size: NSSize(width: 256, height: 256)))
        }
        registration = AttackRegistration(images: frames,reference: HachiwareSprites.shared.frame(pose: .front,index: 0))
    }
    static func frameIndex(time: TimeInterval) -> Int {
        guard time.isFinite && time > 0 else { return 0 }
        return min(frameCount-1, Int(floor(time.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration * Double(frameCount))))
    }
    @discardableResult
    func draw(in rect: NSRect, time: TimeInterval) -> Bool {
        guard isReady, let registration else { return false }
        let index = Self.frameIndex(time: time)
        NSGraphicsContext.current?.imageInterpolation = .high
        frames[index].draw(in: registration.destination(frame: index,in: rect))
        return true
    }
}
