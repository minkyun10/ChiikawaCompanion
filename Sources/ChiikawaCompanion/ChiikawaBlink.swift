import AppKit

/// Composite only the generated eyelid pixels, keeping the approved walking limbs.
final class ChiikawaBlinkArtwork {
    static let shared = ChiikawaBlinkArtwork()
    let source: [NSRect]
    let target: [NSRect]
    private init() {
        if let reference = ChiikawaSprites.shared.frames[.down]?.first,
           let blink = ChiikawaMotionSprites.shared.frames[.blink]?.first {
            source = Self.eyes(in: blink); target = Self.eyes(in: reference)
        } else { source = []; target = [] }
    }
    static func eyes(in image: NSImage) -> [NSRect] {
        guard let data = image.tiffRepresentation, let rep = NSBitmapImageRep(data: data),
              let metrics = AttackBodyMetrics.measure(image) else { return [] }
        let w = rep.pixelsWide, h = rep.pixelsHigh, head = metrics.head
        return [false,true].compactMap { right in
            let search = NSRect(x: head.minX+head.width*(right ? 0.54 : 0.16), y: head.minY+head.height*0.16,
                                width: head.width*0.30, height: head.height*0.42)
            var dark = [Bool](repeating: false,count: w*h), seen = dark
            for y in max(0,Int(search.minY))..<min(h,Int(search.maxY)) {
                for x in max(0,Int(search.minX))..<min(w,Int(search.maxX)) {
                    guard let c = rep.colorAt(x: x,y: y)?.usingColorSpace(.deviceRGB) else { continue }
                    dark[y*w+x] = c.alphaComponent > 0.8 && max(c.redComponent,c.greenComponent,c.blueComponent) < 0.43
                }
            }
            var largest = NSRect.null, size = 0
            for start in dark.indices where dark[start] && !seen[start] {
                var queue = [start], cursor = 0, bounds = NSRect.null; seen[start] = true
                while cursor < queue.count {
                    let n = queue[cursor]; cursor += 1
                    let x = n%w,y = n/w; bounds = bounds.union(NSRect(x: x,y: y,width: 1,height: 1))
                    for (dx,dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
                        let xx = x+dx,yy = y+dy
                        if xx >= 0 && xx < w && yy >= 0 && yy < h {
                            let next = yy*w+xx
                            if dark[next] && !seen[next] { seen[next] = true; queue.append(next) }
                        }
                    }
                }
                if queue.count > size { size = queue.count; largest = bounds }
            }
            guard size > 4 else { return nil }
            return NSRect(x: largest.minX-3,y: CGFloat(h)-largest.maxY-3,width: largest.width+6,height: largest.height+6)
        }
    }
    static func blinkElapsed(time: Double) -> Double? {
        guard time.isFinite else { return nil }
        let phase = max(0,time).truncatingRemainder(dividingBy: 4.8)
        return phase >= 3.7 && phase < 3.97 ? phase-3.7 : nil
    }
    func draw(in rect: NSRect, time: Double) {
        guard source.count == 2, target.count == 2, let elapsed = Self.blinkElapsed(time: time),
              let sequence = ChiikawaMotionSprites.shared.frames[.blink] else { return }
        let image = sequence[ChiikawaMotionSprites.index(.blink, elapsed: elapsed)]
        for i in 0..<2 {
            let dst = NSRect(x: rect.minX+target[i].minX*rect.width/256,y: rect.minY+target[i].minY*rect.height/256,
                             width: target[i].width*rect.width/256,height: target[i].height*rect.height/256)
            image.draw(in: dst, from: source[i], operation: .sourceOver, fraction: 1)
        }
    }
}
