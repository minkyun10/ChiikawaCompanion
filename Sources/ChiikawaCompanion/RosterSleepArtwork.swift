import AppKit

/// Dedicated, approved-identity sleeping illustrations. These are baked into the
/// existing twelve-frame atlas at packaging time; the desktop never decodes or
/// transforms the large originals during its animation loop.
final class RosterSleepArtwork {
    static let canvas = NSSize(width: 256, height: 180)
    let friend: Friend
    let image: NSImage
    let visibleSize: NSSize
    let restingRect: NSRect

    init?(friend: Friend) {
        guard friend.isExpansion,
              let url = HachiwareSprites.assetURL(named: "\(friend.rawValue)-sleep-v47"),
              let data = try? Data(contentsOf: url),
              let bitmap = NSBitmapImageRep(data: data),
              let decoded = bitmap.decodedArtwork else { return nil }
        var left = bitmap.pixelsWide, top = bitmap.pixelsHigh, right = -1, bottom = -1
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.02 {
                left = min(left, x); right = max(right, x)
                top = min(top, y); bottom = max(bottom, y)
            }
        }
        guard right > left, bottom > top,
              let crop = decoded.cropping(to: CGRect(x: left, y: top, width: right-left+1, height: bottom-top+1)) else { return nil }
        self.friend = friend
        visibleSize = NSSize(width: crop.width, height: crop.height)
        image = NSImage(cgImage: crop, size: visibleSize)
        let scale = min(240 / visibleSize.width, 152 / visibleSize.height)
        let size = NSSize(width: visibleSize.width*scale, height: visibleSize.height*scale)
        restingRect = NSRect(x: (Self.canvas.width-size.width)/2, y: 12, width: size.width, height: size.height)
    }

    func draw(phase: Double) {
        let phase = phase.isFinite ? phase-floor(phase) : 0
        let inhale = CGFloat((1-cos(2 * .pi*phase))/2)
        // One quiet vertical breath, anchored to the mat. Width and ground
        // contact never oscillate, and the face, ears and tail stay attached.
        let rect = NSRect(x: restingRect.minX, y: restingRect.minY,
                          width: restingRect.width, height: restingRect.height+1.6*inhale)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: rect)
    }
}
