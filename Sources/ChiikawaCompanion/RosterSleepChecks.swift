import AppKit

extension SelfTest {
    static func runRosterSleepChecks(check: (Bool, String) -> Void) {
        var sourcePixels = Set<Data>()
        for friend in Friend.expansionOrder {
            let prefix = "\(friend.name) sleep: "
            guard let art = RosterSleepArtwork(friend: friend), let rig = RosterNativeRig(friend: friend) else {
                check(false, prefix+"dedicated sleeping source is available"); continue
            }
            let ratio = art.visibleSize.width/art.visibleSize.height
            check(ratio > 1.4 && ratio < 2.7 && art.visibleSize.width > 1000,
                  prefix+"high-resolution original is composed as a complete horizontal sleeper")
            sourcePixels.insert(visiblePixels(art.image, edge: 128))
            let sprites = RosterSprites.shared(friend)
            let frames = sprites.actions[.sleep] ?? []
            check(frames.count == 12 && frames.allSatisfy { $0.size == RosterSleepArtwork.canvas },
                  prefix+"the packaged breathing loop has twelve fixed-size frames")
            var margins = true, bounds: [NSRect] = []
            for frame in frames {
                let bitmap = RosterNativeRig.bitmap(RosterSleepArtwork.canvas) {
                    frame.draw(in: NSRect(origin: .zero, size: RosterSleepArtwork.canvas))
                }
                var visible = NSRect.null
                for y in 0..<bitmap.pixelsHigh { for x in 0..<bitmap.pixelsWide {
                    let alpha = bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0
                    if x < 4 || x >= bitmap.pixelsWide-4 || y < 4 || y >= bitmap.pixelsHigh-4 {
                        margins = margins && alpha < 0.02
                    }
                    if alpha > 0.2 { visible = visible.union(NSRect(x: x, y: y, width: 1, height: 1)) }
                }}
                bounds.append(visible)
            }
            check(margins && bounds.allSatisfy { !$0.isNull && $0.width > 225 },
                  prefix+"ears, head ornaments, tail and mat fit without clipping or opaque borders")
            let bed = NSRect(x: 0, y: 0, width: 163, height: 83)
            let fitted = HomeArtwork.fitted(sprites.sleepViewport.size, in: bed)
            check(fitted.width > 145 && fitted.height <= bed.height && bed.contains(fitted)
                  && sprites.sleepViewport.minY >= 0 && sprites.sleepViewport.maxY <= RosterSleepArtwork.canvas.height,
                  prefix+"one fixed visible-art viewport uses the real house bed without shrinking into transparent padding")
            check(bounds.count == 12 && bounds.allSatisfy {
                abs($0.maxY-bounds[0].maxY) <= 1 && abs($0.width-bounds[0].width) <= 1
            }, prefix+"breathing keeps the mat grounded and preserves horizontal registration")
            func rendered(_ phase: Double) -> NSImage {
                let bitmap = rig.action(.sleep, phase: phase)
                return NSImage(cgImage: bitmap.cgImage!, size: RosterSleepArtwork.canvas)
            }
            check(visiblePixels(rendered(0), edge: 256) == visiblePixels(rendered(1), edge: 256)
                  && visiblePixels(rendered(0), edge: 256) != visiblePixels(rendered(0.5), edge: 256),
                  prefix+"quiet inhale changes the drawing and joins the loop continuously")
            check([256, 512].allSatisfy { edge in
                [0, 3, 6, 9, 11].allSatisfy { index in
                    frames.count == 12 && visiblePixels(frames[index], edge: edge)
                        == visiblePixels(rendered(Double(index)/12), edge: edge)
                }
            }, prefix+"bundled frame order and visible pixels match the source renderer at 1x and Retina")
        }
        check(sourcePixels.count == Friend.expansionOrder.count,
              "each expansion companion has its own distinct sleeping illustration")
        check(RosterSleepArtwork(friend: .hachiware) == nil && RosterSleepArtwork(friend: .chiikawa) == nil,
              "the original Hachiware and Chiikawa sleep pipelines remain separate")
        check(RosterAction.sleep.cycle == 3.6, "sleep uses a quiet 3.6-second breathing cycle")
    }
}
