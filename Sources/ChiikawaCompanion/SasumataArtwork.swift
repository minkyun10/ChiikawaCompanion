import AppKit

/// Chiikawa's approved silhouette, white studs and grip, with only the paint varied.
enum SasumataArtwork {
    static let skyBlue = NSColor(hex: 0x7DA6BC)
    static let ink = NSColor(hex: 0x684A42)

    static func carriedRect(back: Bool) -> NSRect {
        NSRect(x: back ? 165 : 151, y: 17, width: 90, height: 212)
    }

    static func draw(in rect: NSRect, color: NSColor) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        cg.translateBy(x: rect.minX, y: rect.minY)
        cg.scaleBy(x: rect.width / 256, y: rect.height / 256)
        cg.translateBy(x: 128, y: 128); cg.rotate(by: -0.28); cg.translateBy(x: -128, y: -128)
        ChiikawaItemArtwork.stroke([NSPoint(x: 128, y: 20), NSPoint(x: 128, y: 178)], width: 17, color: ink)
        ChiikawaItemArtwork.stroke([NSPoint(x: 128, y: 20), NSPoint(x: 128, y: 178)], width: 10, color: color)
        ChiikawaItemArtwork.stroke([NSPoint(x: 128, y: 20), NSPoint(x: 128, y: 43)], width: 9, color: .white)
        let fork = NSBezierPath(); fork.move(to: NSPoint(x: 80, y: 227))
        fork.curve(to: NSPoint(x: 176, y: 227), controlPoint1: NSPoint(x: 60, y: 153), controlPoint2: NSPoint(x: 196, y: 153))
        fork.lineCapStyle = .round
        fork.lineWidth = 22; ink.setStroke(); fork.stroke()
        fork.lineWidth = 13; color.setStroke(); fork.stroke()
        for point in [NSPoint(x: 87, y: 216), NSPoint(x: 99, y: 191), NSPoint(x: 128, y: 185), NSPoint(x: 157, y: 191), NSPoint(x: 169, y: 216)] {
            ChiikawaItemArtwork.oval(NSRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10), color: .white, line: 2)
        }
        cg.restoreGState()
    }

    /// Add the same white details to the existing v7 held pose without repainting its body.
    /// Coordinates are in its original 475 × 444 crop, measured from the top left.
    static func drawHeldPoseDetails(in rect: NSRect) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.minY)
        cg.scaleBy(x: rect.width / 475, y: rect.height / 444)
        for point in [NSPoint(x: 373, y: 123), NSPoint(x: 365, y: 158), NSPoint(x: 389, y: 183), NSPoint(x: 423, y: 170), NSPoint(x: 445, y: 146)] {
            ChiikawaItemArtwork.oval(NSRect(x: point.x - 5, y: 444 - point.y - 5, width: 10, height: 10), color: .white, line: 2)
        }
        ChiikawaItemArtwork.stroke([NSPoint(x: 195, y: 444 - 394), NSPoint(x: 207, y: 444 - 380)], width: 8, color: .white)
        cg.restoreGState()
    }
}
