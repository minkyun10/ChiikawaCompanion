import AppKit

/// Facial decals are anchored to the approved front rig, not to separately
/// generated heads. The original ears, brow arches, cheeks and body always draw.
final class UsagiFace {
    let parts: [String: NSImage]
    let patches: [(NSRect, NSImage)]
    let sourceSize: NSSize
    let bodyImage: NSImage
    static let mouthArea = NSRect(x: 109, y: 239, width: 44, height: 52)
    static let eyeAreas = [NSRect(x: 76, y: 206, width: 31, height: 31),
                           NSRect(x: 154, y: 206, width: 30, height: 31)]

    init?(body: NSImage) {
        var parts: [String: NSImage] = [:]
        let names = ["cheer-mouth", "shout-mouth", "curious-mouth", "sleep-mouth",
                     "sleep-left-eye", "sleep-right-eye", "blink-left-eye", "blink-right-eye"]
        for name in names {
            guard let url = HachiwareSprites.assetURL(named: "usagi-face-\(name)-v44"),
                  let image = NSImage(contentsOf: url) else { return nil }
            parts[name] = image
        }
        guard let data = body.tiffRepresentation, let source = NSBitmapImageRep(data: data) else { return nil }
        sourceSize = body.size
        bodyImage = body
        // These small opaque patches replace the original ink with the adjacent
        // cream color, row by row. They never reach the cheek or brow artwork.
        var patches: [(NSRect, NSImage)] = []
        for area in [Self.mouthArea] + Self.eyeAreas {
            let width = Int(area.width), height = Int(area.height)
            let patch = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
            for y in 0..<height {
                let sy = Int(area.minY) + y
                // For the eyes, use the clean central face to avoid pink cheeks.
                let sampleLeft = area == Self.mouthArea ? 107 : 111
                let sampleRight = area == Self.mouthArea ? 155 : 148
                let left = source.colorAt(x: sampleLeft, y: sy)!, right = source.colorAt(x: sampleRight, y: sy)!
                for x in 0..<width {
                    let t = CGFloat(x) / CGFloat(width - 1)
                    patch.setColor(NSColor(deviceRed: left.redComponent * (1-t) + right.redComponent * t,
                        green: left.greenComponent * (1-t) + right.greenComponent * t,
                        blue: left.blueComponent * (1-t) + right.blueComponent * t, alpha: 1), atX: x, y: y)
                }
            }
            let image = NSImage(size: area.size); image.addRepresentation(patch)
            patches.append((area, image))
        }
        self.parts = parts; self.patches = patches
    }

    /// Source rectangles use PNG's top-left origin; native sprites use bottom-left.
    func destination(_ source: NSRect, in body: NSRect) -> NSRect {
        NSRect(x: body.minX + source.minX / sourceSize.width * body.width,
               y: body.maxY - source.maxY / sourceSize.height * body.height,
               width: source.width / sourceSize.width * body.width,
               height: source.height / sourceSize.height * body.height)
    }

    func draw(_ action: RosterAction, phase: Double, in body: NSRect) {
        let mouth: String?
        switch action {
        case .laugh, .wake, .keepsake: mouth = "cheer"
        case .attack: mouth = "shout"
        case .surprised: mouth = "curious"
        case .sleep: mouth = "sleep"
        default: mouth = nil
        }
        let eyelids = action == .sleep ? "sleep" : action == .wake && phase < 0.25 ? "blink" : nil
        guard mouth != nil || eyelids != nil else { return }
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState()
        // Explicit clips keep generated pixels inside the small facial regions,
        // including alpha fringes. An expression can never replace the silhouette.
        if let mouth, let image = parts[mouth + "-mouth"] {
            context.saveGState(); context.clip(to: destination(Self.mouthArea, in: body))
            patches[0].1.draw(in: destination(patches[0].0, in: body))
            let width: CGFloat = mouth == "sleep" ? 34 : 38
            let height = min(46, width * image.size.height / image.size.width)
            let preservesMuzzle = mouth == "cheer" || mouth == "shout"
            let top: CGFloat = mouth == "sleep" ? 247 : preservesMuzzle ? 250 : 242
            image.draw(in: destination(NSRect(x: 131-width/2, y: top, width: width, height: height), in: body))
            if preservesMuzzle {
                // Preserve the approved omega-shaped upper lip over the open mouth.
                let muzzle = NSRect(x: 109, y: 239, width: 44, height: 16)
                let source = NSRect(x: muzzle.minX, y: sourceSize.height-muzzle.maxY, width: muzzle.width, height: muzzle.height)
                bodyImage.draw(in: destination(muzzle, in: body), from: source, operation: .sourceOver, fraction: 1)
            }
            context.restoreGState()
        }
        if let eyelids {
            for (index, side) in ["left", "right"].enumerated() {
                let area = Self.eyeAreas[index], image = parts[eyelids + "-" + side + "-eye"]!
                context.saveGState(); context.clip(to: destination(area, in: body))
                patches[index+1].1.draw(in: destination(area, in: body))
                let width: CGFloat = 24, height = width * image.size.height / image.size.width
                image.draw(in: destination(NSRect(x: area.midX-width/2, y: 222-height/2, width: width, height: height), in: body))
                context.restoreGState()
            }
        }
        context.restoreGState()
    }
}
