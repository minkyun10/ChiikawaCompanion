import AppKit

extension SelfTest {
    static func runSasumataDesignChecks(check: (Bool, String) -> Void) {
        for size in [64, 256] {
            let rect = NSRect(x: 0, y: 0, width: size, height: size)
            let blue = RosterNativeRig.bitmap(rect.size) { ItemArtwork.draw(.sasumata, in: rect) }
            let pink = RosterNativeRig.bitmap(rect.size) { ChiikawaItemArtwork.draw(.pinkSasumata, in: rect) }
            var sameAlpha = true, sameWhite = true, whiteCount = 0, paintedDifference = false
            for y in 0..<size { for x in 0..<size {
                let a = blue.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                let b = pink.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                sameAlpha = sameAlpha && abs(a.alphaComponent - b.alphaComponent) < 0.001
                func white(_ c: NSColor) -> Bool {
                    c.alphaComponent > 0.9 && min(c.redComponent, c.greenComponent, c.blueComponent) > 0.96
                }
                // Antialiased white edges blend with different paint underneath.
                // Require each white core to remain white in both colour variants.
                func whiteCore(_ c: NSColor) -> Bool {
                    c.alphaComponent > 0.99 && min(c.redComponent, c.greenComponent, c.blueComponent) > 0.995
                }
                sameWhite = sameWhite && (!whiteCore(a) || white(b)) && (!whiteCore(b) || white(a))
                if white(a) { whiteCount += 1 }
                if a.alphaComponent > 0.99 && b.alphaComponent > 0.99 && abs(a.redComponent - b.redComponent) > 0.04 {
                    paintedDifference = true
                }
            } }
            check(sameAlpha && sameWhite && whiteCount > size / 8 && paintedDifference,
                  "\(size)px blue and pink sasumata share their silhouette and white cores (alpha=\(sameAlpha), white=\(sameWhite), whitePixels=\(whiteCount), paint=\(paintedDifference))")
        }
        let canvas = NSRect(x: 0, y: 0, width: 256, height: 256)
        var sameCarriedSilhouette = true
        for pose in [HachiwarePose.front, .back, .side, .frontDiagonal, .backDiagonal] {
            for facing: CGFloat in [-1, 1] { for behind in [false, true] {
                let blue = RosterNativeRig.bitmap(canvas.size) {
                    ItemArtwork.drawEquipped(.sasumata, in: canvas, pose: pose, facing: facing, time: 0, behind: behind)
                }
                let pink = RosterNativeRig.bitmap(canvas.size) {
                    ChiikawaItemArtwork.drawEquipped(.pinkSasumata, in: canvas, pose: pose, facing: facing, behind: behind)
                }
                sameCarriedSilhouette = sameCarriedSilhouette && (0..<256).allSatisfy { y in
                    (0..<256).allSatisfy { x in blue.bitmapData![y * blue.bytesPerRow + x * 4 + 3] == pink.bitmapData![y * pink.bytesPerRow + x * 4 + 3] }
                }
            } }
        }
        check(sameCarriedSilhouette, "carried blue and pink weapons keep the same proportions and layer placement in every direction")
        let held = NSBitmapImageRep(data: HachiwareActions.shared.frames[HachiwareAction.sasumata.rawValue].tiffRepresentation!)!
        // The approved v7 crop is registered at scale 208 / 384 and bottom margin 20.
        let scale: CGFloat = 208 / 384
        let points = [NSPoint(x: 373, y: 123), NSPoint(x: 365, y: 158), NSPoint(x: 389, y: 183),
                      NSPoint(x: 423, y: 170), NSPoint(x: 445, y: 146), NSPoint(x: 201, y: 387)]
        check(points.allSatisfy { point in
            let x = Int((-13.9166666667 + point.x * scale).rounded())
            let y = Int((256 - (1.0416666667 + (444 - point.y) * scale)).rounded())
            let c = held.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
            return c.alphaComponent > 0.9 && min(c.redComponent, c.greenComponent, c.blueComponent) > 0.9
        }, "the existing held pose retains five white fork studs and a white grip cap")
    }

    static func renderSasumataReview(to path: String) {
        let root = URL(fileURLWithPath: path, isDirectory: true)
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        func picture(_ name: String, width: Int, height: Int, draw: () -> Void) {
            png(width: width, height: height, to: root.appendingPathComponent(name + ".png")) {
                NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
                draw()
            }
        }
        picture("weapon-comparison", width: 720, height: 400) {
            ChiikawaItemArtwork.draw(.pinkSasumata, in: NSRect(x: 85, y: 60, width: 256, height: 300))
            ItemArtwork.draw(.sasumata, in: NSRect(x: 390, y: 60, width: 256, height: 300))
            for (title, x) in [("치이카와 · 기준", 160), ("하치와레 · 하늘색", 455)] {
                (title as NSString).draw(at: NSPoint(x: x, y: 25), withAttributes: [.font: NSFont.systemFont(ofSize: 18), .foregroundColor: FriendArtwork.ink])
            }
        }
        picture("held-and-attacks", width: 1440, height: 400) {
            FriendArtwork.draw(.hachiware, in: NSRect(x: 30, y: 60, width: 300, height: 300), action: .sasumata)
            FriendArtwork.draw(.hachiware, in: NSRect(x: 390, y: 60, width: 300, height: 300), action: .attack, actionTime: 0.3)
            FriendArtwork.draw(.chiikawa, in: NSRect(x: 750, y: 60, width: 300, height: 300), action: .attack, actionTime: 0.3)
            FriendArtwork.draw(.hachiware, in: NSRect(x: 1110, y: 60, width: 300, height: 300), action: .attack, actionTime: 0.3, hachiwareMonster: true)
            for (n, title) in ["기존 무기 들기 · 흰 디테일 보완", "하치와레 공격", "치이카와 공격 · 기준", "변신 상태 공격"].enumerated() {
                (title as NSString).draw(at: NSPoint(x: n * 360 + 65, y: 25), withAttributes: [.font: NSFont.systemFont(ofSize: 17), .foregroundColor: FriendArtwork.ink])
            }
        }
        picture("armed-eight-directions", width: 1024, height: 576) {
            for (n, direction) in ChiikawaDirection.allCases.enumerated() {
                let facing: CGFloat = [.right, .upRight, .downRight].contains(direction) ? 1 : -1
                let pose: HachiwarePose = direction == .up ? .back : direction == .down ? .front
                    : [.left, .right].contains(direction) ? .side
                    : [.upLeft, .upRight].contains(direction) ? .backDiagonal : .frontDiagonal
                let rect = NSRect(x: n % 4 * 256, y: (1 - n / 4) * 288 + 24, width: 256, height: 256)
                FriendArtwork.draw(.hachiware, in: rect, walking: true, facing: facing, walkPhase: 0.3, pose: pose, equipped: .sasumata)
                (direction.rawValue as NSString).draw(at: NSPoint(x: rect.minX + 85, y: rect.minY - 12), withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: FriendArtwork.ink])
            }
        }
        print("Sasumata colour comparison, held pose, normal/monster attacks and eight directions exported.")
    }
}
