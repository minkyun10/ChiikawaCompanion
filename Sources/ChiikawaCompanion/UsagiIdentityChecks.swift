import AppKit

extension SelfTest {
    static func runUsagiIdentityChecks(check: (Bool, String) -> Void) {
        guard let rig = RosterSprites.shared(.usagi).rig, let face = rig.usagiFace else {
            check(false, "Usagi loads the approved body and local facial decals"); return
        }
        check(face.parts.count == 8 && rig.expressions.isEmpty,
              "Usagi uses facial decals instead of replacing entire expression bodies")
        let size = rig.canvas, body = rig.bodyRect(.front, y: 44)
        let base = RosterNativeRig.bitmap(size) { rig.drawBody(.wave, y: 44, phase: 0) }
        let allowed = ([UsagiFace.mouthArea] + UsagiFace.eyeAreas).map { face.destination($0, in: body).insetBy(dx: -1, dy: -1) }
        for action in RosterAction.available(for: .usagi) {
            var unchangedOutsideFace = true, silhouetteUnchanged = true, faceDiffers = false
            for phase in [0.0, 0.25, 0.5, 0.75] {
                let shown = RosterNativeRig.bitmap(size) { rig.drawBody(action, y: 44, phase: phase) }
                let original = base.bitmapData!, actual = shown.bitmapData!
                for y in 0..<base.pixelsHigh { for x in 0..<base.pixelsWide {
                    let offset = y * base.bytesPerRow + x * 4
                    let same = (0..<4).allSatisfy { original[offset+$0] == actual[offset+$0] }
                    // A local face patch may make translucent cream opaque;
                    // its coverage must not create or remove silhouette pixels.
                    silhouetteUnchanged = silhouetteUnchanged && (original[offset+3] > 127) == (actual[offset+3] > 127)
                    let point = NSPoint(x: CGFloat(x)+0.5, y: size.height-CGFloat(y)-0.5)
                    if allowed.contains(where: { $0.contains(point) }) { faceDiffers = faceDiffers || !same }
                    else { unchangedOutsideFace = unchangedOutsideFace && same }
                }}
            }
            check(unchangedOutsideFace && silhouetteUnchanged,
                  "Usagi \(action.rawValue): ears, brow arches, cheeks and body pixels stay identical across facial changes")
            if [.laugh, .attack, .surprised, .sleep, .wake, .keepsake].contains(action) {
                check(faceDiffers, "Usagi \(action.rawValue): the facial region visibly changes on the fixed body")
            }
        }
        if Bundle.main.bundleURL.pathExtension == "app" {
            check(["laugh","attack","surprised","sleep","neutral"].allSatisfy {
                Bundle.main.url(forResource: "usagi-expression-\($0)-v38", withExtension: "png") == nil
            }, "packaged Usagi excludes the superseded whole-body expression drawings")
        }
    }
}
