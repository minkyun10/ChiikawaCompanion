import AppKit

extension SelfTest {
    static func runNewFriendChecks(check: (Bool, String) -> Void) {
        if Bundle.main.bundleURL.pathExtension == "app" {
            check(HachiwareSprites.assetURL(named: "absent-optional-expression") == nil,
                  "packaged missing art stays absent without searching the development checkout")
            check(RecordingCatalog.resourceURL(file: "absent-optional-voice.json") == nil,
                  "packaged missing voice stays absent without searching the development checkout")
        }
        for friend in Friend.expansionOrder.filter(\.isNewSingleItemFriend) {
        guard let rig = RosterSprites.shared(friend).rig, let face = rig.newFace else {
            check(false, "New friend loads its registered body and facial rig"); continue
        }
        let size = rig.canvas, body = rig.bodyRect(.front, y: 44)
        let base = RosterNativeRig.bitmap(size) { rig.drawBody(.wave, y: 44, phase: 0) }
        let allowed = face.areas.map { face.destination($0, in: body).insetBy(dx: -1, dy: -1) }
        for action in RosterAction.available(for: friend) {
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
                  "\(friend.name) \(action.rawValue): ears, brow arches, cheeks and body pixels stay identical across facial changes")
            if [.laugh, .surprised, .sleep, .wake].contains(action) {
                check(faceDiffers, "\(friend.name) \(action.rawValue): the facial region visibly changes on the fixed body")
            }
        }
        }
    }
}
