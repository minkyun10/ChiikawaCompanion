import AppKit

/// Chiikawa owns its own artwork; both companions use the same attack cadence.
final class ChiikawaAttackSprites {
    static let shared = ChiikawaAttackSprites()
    static let assetName = "chiikawa-attack-v24"
    static var frameCount: Int { WeaponAttackSprites.frameCount }
    static var cycleDuration: TimeInterval { WeaponAttackSprites.cycleDuration }
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
        registration = AttackRegistration(images: frames,reference: ChiikawaSprites.shared.frames[.down]?.first)
    }
    static func frameIndex(time: TimeInterval) -> Int { WeaponAttackSprites.frameIndex(time: time) }
    @discardableResult
    func draw(in rect: NSRect, time: TimeInterval) -> Bool {
        guard isReady, let registration else { return false }
        let index = Self.frameIndex(time: time)
        NSGraphicsContext.current?.imageInterpolation = .high
        frames[index].draw(in: registration.destination(frame: index,in: rect))
        return true
    }
}
