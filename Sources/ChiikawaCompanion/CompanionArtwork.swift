import AppKit

final class HachiwareActions {
    static let shared = HachiwareActions()
    static let assetName = "hachiware-actions-v7"
    private(set) var frames: [NSImage] = []
    var isReady: Bool { frames.count == HachiwareAction.allCases.count }

    private init() {
        guard let url = HachiwareSprites.assetURL(named: Self.assetName),
              let data = try? Data(contentsOf: url), let rep = NSBitmapImageRep(data: data),
              let atlas = rep.cgImage else { return }
        var parts: [(CGImage, NSRect)] = []
        for index in 0..<8 {
            let col = index % 4, row = index / 4
            // The sasumata extends into the nominal last gutter. Cut in the actual
            // transparent gap so it is whole and never leaks into the bag sprite.
            let edges = row == 1 ? [0, 444, 887, 1362, atlas.width] : [0, 444, 887, 1331, atlas.width]
            let x = edges[col], y = row * atlas.height / 2
            let width = edges[col + 1] - x
            let height = (row + 1) * atlas.height / 2 - y
            guard let crop = atlas.cropping(to: CGRect(x: x, y: y, width: width, height: height)) else { return }
            let bitmap = NSBitmapImageRep(cgImage: crop)
            var left = width, right = 0, top = height, bottom = 0
            for py in 0..<height {
                for px in 0..<width where (bitmap.colorAt(x: px, y: py)?.alphaComponent ?? 0) > 0.25 {
                    left = min(left, px); right = max(right, px)
                    top = min(top, py); bottom = max(bottom, py)
                }
            }
            guard right > left, bottom > top else { return }
            parts.append((crop, NSRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)))
        }
        let bodyHeight = parts.prefix(3).map { $0.1.height }.sorted()[1]
        for (image, bounds) in parts {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 1024, bitsPerPixel: 32)!
            guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
            context.imageInterpolation = .high
            let scale = min(208 / bodyHeight, 238 / bounds.width)
            let drawRect = NSRect(x: 128 - bounds.midX * scale,
                y: 20 - (CGFloat(image.height) - bounds.maxY) * scale,
                width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)).draw(in: drawRect)
            context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
            frames.append(NSImage(cgImage: bitmap.cgImage!, size: NSSize(width: 256, height: 256)))
        }
    }
    @discardableResult
    func draw(_ action: HachiwareAction, in rect: NSRect, time: Double) -> Bool {
        guard isReady, let cg = NSGraphicsContext.current?.cgContext else { return false }
        let length = min(rect.width, rect.height)
        cg.saveGState()
        cg.translateBy(x: rect.midX, y: rect.midY - length * 0.30)
        let sway = action == .guitar ? sin(time * 6) * 0.025 : action == .laugh ? sin(time * 7) * 0.012 : 0
        cg.rotate(by: sway)
        let bounce = action == .laugh ? abs(sin(time * 7)) * length * 0.015 : 0
        frames[action.rawValue].draw(in: NSRect(x: -length / 2, y: -length * 0.20 + bounce,
                                               width: length, height: length))
        cg.restoreGState()
        if action == .camera && time.truncatingRemainder(dividingBy: 1.8) < 0.16 {
            FriendArtwork.spark(rect.midX + length * 0.13, rect.midY - length * 0.15, size: length * 0.055)
        }
        if action == .guitar {
            for index in 0..<2 {
                let rise = (time * 0.65 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
                (index == 0 ? "♪" : "♫" as NSString).draw(at: NSPoint(
                    x: rect.midX + length * (index == 0 ? 0.32 : -0.40),
                    y: rect.midY + length * CGFloat(rise * 0.25)),
                    withAttributes: [.font: NSFont.systemFont(ofSize: length * 0.13, weight: .medium),
                                     .foregroundColor: NSColor(hex: 0x7EA6B9, alpha: 1 - rise * 0.7)])
            }
        }
        return true
    }
}

/// Native accessories stay attached to the existing twelve-frame walk in every direction.
/// These are drawn in the same 256-point registration as the walking sprites.
enum ItemArtwork {
    static let ink = NSColor(hex: 0x48332D)
    static let blue = NSColor(hex: 0x7DA6BC)
    static func path(_ points: [NSPoint], width: CGFloat, color: NSColor) {
        let p = NSBezierPath(); p.move(to: points[0]); points.dropFirst().forEach { p.line(to: $0) }
        p.lineWidth = width; p.lineCapStyle = .round; p.lineJoinStyle = .round
        color.setStroke(); p.stroke()
    }
    static func line(_ points: [NSPoint], width: CGFloat = 8, fill: NSColor = blue) {
        path(points, width: width + 5, color: ink); path(points, width: width, color: fill)
    }
    static func box(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
        let p = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        fill.setFill(); p.fill(); ink.setStroke(); p.lineWidth = 4.5; p.stroke()
    }
    static func oval(_ rect: NSRect, fill: NSColor, width: CGFloat = 4) {
        let p = NSBezierPath(ovalIn: rect); fill.setFill(); p.fill()
        ink.setStroke(); p.lineWidth = width; p.stroke()
    }
    static func draw(_ item: CompanionItem, in rect: NSRect, time: Double = 0, strap: Bool = true) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.minY)
        cg.scaleBy(x: rect.width / 256, y: rect.height / 256)
        switch item {
        case .camera:
            if strap { line([NSPoint(x: 64, y: 124), NSPoint(x: 70, y: 200), NSPoint(x: 190, y: 200), NSPoint(x: 194, y: 124)], width: 9) }
            box(NSRect(x: 48, y: 67, width: 162, height: 105), radius: 10, fill: NSColor(hex: 0x4C4C4B))
            box(NSRect(x: 48, y: 143, width: 162, height: 29), radius: 5, fill: NSColor(hex: 0xE0D4C6))
            box(NSRect(x: 68, y: 172, width: 25, height: 12), radius: 3, fill: NSColor(hex: 0xE0D4C6))
            oval(NSRect(x: 101, y: 83, width: 62, height: 62), fill: NSColor(hex: 0xD5CEC7))
            oval(NSRect(x: 113, y: 95, width: 38, height: 38), fill: NSColor(hex: 0x2E3239))
            oval(NSRect(x: 122, y: 116, width: 10, height: 10), fill: .white, width: 0)
            box(NSRect(x: 177, y: 150, width: 15, height: 9), radius: 1, fill: .white)
        case .guitar:
            cg.translateBy(x: 125, y: 123); cg.rotate(by: 0.40); cg.translateBy(x: -125, y: -123)
            let body = NSBezierPath()
            body.move(to: NSPoint(x: 117, y: 166))
            body.curve(to: NSPoint(x: 52, y: 152), controlPoint1: NSPoint(x: 75, y: 202), controlPoint2: NSPoint(x: 35, y: 180))
            body.curve(to: NSPoint(x: 36, y: 82), controlPoint1: NSPoint(x: 70, y: 128), controlPoint2: NSPoint(x: 10, y: 130))
            body.curve(to: NSPoint(x: 125, y: 65), controlPoint1: NSPoint(x: 35, y: 40), controlPoint2: NSPoint(x: 100, y: 35))
            body.curve(to: NSPoint(x: 136, y: 120), controlPoint1: NSPoint(x: 155, y: 93), controlPoint2: NSPoint(x: 110, y: 105))
            body.curve(to: NSPoint(x: 117, y: 166), controlPoint1: NSPoint(x: 172, y: 150), controlPoint2: NSPoint(x: 148, y: 177))
            body.close(); NSColor(hex: 0xDDA768).setFill(); body.fill(); ink.setStroke(); body.lineWidth = 5; body.stroke()
            box(NSRect(x: 112, y: 120, width: 100, height: 25), radius: 3, fill: NSColor(hex: 0xA8754D))
            box(NSRect(x: 200, y: 113, width: 29, height: 39), radius: 4, fill: NSColor(hex: 0xDDA768))
            oval(NSRect(x: 75, y: 108, width: 43, height: 43), fill: NSColor(hex: 0x6C4833))
            box(NSRect(x: 57, y: 88, width: 10, height: 42), radius: 1, fill: NSColor(hex: 0x6C4833))
            for y in [123, 129, 135] { path([NSPoint(x: 61, y: y), NSPoint(x: 219, y: y)], width: 1.8, color: ink) }
        case .sasumata:
            cg.translateBy(x: 128, y: 128); cg.rotate(by: -0.33); cg.translateBy(x: -128, y: -128)
            line([NSPoint(x: 128, y: 24), NSPoint(x: 128, y: 174)], width: 12)
            let fork = NSBezierPath(); fork.move(to: NSPoint(x: 88, y: 227))
            fork.curve(to: NSPoint(x: 168, y: 227), controlPoint1: NSPoint(x: 71, y: 157), controlPoint2: NSPoint(x: 185, y: 157))
            fork.lineCapStyle = .round; fork.lineWidth = 23; ink.setStroke(); fork.stroke()
            fork.lineWidth = 13; blue.setStroke(); fork.stroke()
        case .bag:
            if strap { line([NSPoint(x: 65, y: 143), NSPoint(x: 66, y: 207), NSPoint(x: 191, y: 207), NSPoint(x: 191, y: 143)], width: 10) }
            box(NSRect(x: 53, y: 55, width: 152, height: 115), radius: 28, fill: NSColor(hex: 0xDDA768))
            box(NSRect(x: 58, y: 113, width: 143, height: 57), radius: 17, fill: NSColor(hex: 0xEDBF82))
            box(NSRect(x: 115, y: 108, width: 26, height: 22), radius: 5, fill: NSColor(hex: 0x96714C))
        }
        cg.restoreGState()
    }
    static func drawEquipped(_ item: CompanionItem, in rect: NSRect, pose: HachiwarePose,
                             facing: CGFloat, time: Double, behind: Bool) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        let length = min(rect.width, rect.height)
        cg.saveGState(); cg.translateBy(x: rect.midX - length / 2, y: rect.midY - length / 2)
        cg.scaleBy(x: length / 256, y: length / 256)
        if pose.canMirror && facing > 0 { cg.translateBy(x: 256, y: 0); cg.scaleBy(x: -1, y: 1) }
        let back = pose == .back || pose == .backDiagonal
        let side = pose == .side
        if behind {
            if back && item == .sasumata { draw(item, in: NSRect(x: 153, y: 16, width: 105, height: 224)) }
        } else if back {
            if item != .sasumata {
                if item == .camera {
                    line([NSPoint(x: 81, y: 105), NSPoint(x: 106, y: 84), NSPoint(x: 151, y: 84), NSPoint(x: 176, y: 105)], width: 5)
                } else {
                    line([NSPoint(x: 77, y: 103), NSPoint(x: 177, y: 55)], width: item == .guitar ? 7 : 6,
                         fill: item == .guitar ? NSColor(hex: 0xA8754D) : blue)
                }
            }
        } else {
            switch item {
            case .camera:
                line([NSPoint(x: side ? 82 : 78, y: 103), NSPoint(x: side ? 65 : 105, y: 76),
                      NSPoint(x: side ? 102 : 162, y: 76), NSPoint(x: side ? 122 : 181, y: 103)], width: 5)
                draw(item, in: NSRect(x: side ? 27 : 65, y: 31, width: side ? 96 : 130, height: 110), strap: false)
            case .guitar:
                draw(item, in: NSRect(x: side ? 32 : 51, y: 22, width: side ? 150 : 170, height: 135))
            case .sasumata:
                draw(item, in: NSRect(x: 121, y: 17, width: 121, height: 215))
            case .bag:
                line([NSPoint(x: 73, y: 103), NSPoint(x: 182, y: 67)], width: 6)
                draw(item, in: NSRect(x: 148, y: 28, width: 81, height: 86), strap: false)
            }
            // Small paws rest in front of the held object, instead of leaving it floating.
            if item != .bag {
                oval(NSRect(x: item == .sasumata ? 159 : side ? 73 : 83, y: item == .sasumata ? 79 : 69,
                            width: 23, height: 18), fill: NSColor(hex: 0xFFFDFC), width: 3)
            }
        }
        cg.restoreGState()
    }
}
