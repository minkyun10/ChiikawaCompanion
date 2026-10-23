import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    /// Review the actual bundled frames, both enlarged and inside the real
    /// shared-house geometry, without changing user preferences or playing audio.
    static func renderSleepReview(to path: String) {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let friends = Friend.expansionOrder
        let background = NSColor(hex: 0xF1EEE4)
        let text: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 19, weight: .medium), .foregroundColor: FriendArtwork.ink]
        func preview(_ index: Int) -> NSBitmapImageRep {
            RosterNativeRig.bitmap(NSSize(width: 1200, height: 580)) {
                background.setFill(); NSRect(x: 0, y: 0, width: 1200, height: 580).fill()
                ("캐릭터별 수면 · 전용 원화 + 조용한 숨쉬기" as NSString)
                    .draw(at: NSPoint(x: 24, y: 545), withAttributes: text)
                for (i, friend) in friends.enumerated() {
                    let cell = NSRect(x: CGFloat(i%3)*400+16, y: CGFloat(1-i/3)*252+38, width: 368, height: 222)
                    RosterSprites.shared(friend).draw(action: .sleep, in: cell,
                        elapsed: (Double(index)+0.01)/12*RosterAction.sleep.cycle)
                    (friend.name as NSString).draw(at: NSPoint(x: cell.minX+145, y: cell.minY-13), withAttributes: text)
                }
            }
        }
        try! preview(3).representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("sleep-characters-v47.png"))
        let gif = CGImageDestinationCreateWithURL(directory.appendingPathComponent("sleep-breathing-v47.gif") as CFURL,
                                                   UTType.gif.identifier as CFString, 12, nil)!
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for index in 0..<12 {
            CGImageDestinationAddImage(gif, preview(index).cgImage!,
                [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: RosterAction.sleep.cycle/12]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(gif))
        let now = Date(timeIntervalSince1970: 1000)
        func occupant(_ friend: Friend) -> HomeOccupant {
            var routine = HomeRoutine(now: now)
            routine.request(now: now); _ = routine.arrive(contact: .zero, entrance: .zero, now: now)
            routine.advance(now: now.addingTimeInterval(1))
            return HomeOccupant(friend: friend, routine: routine)
        }
        png(width: 1200, height: 720, to: directory.appendingPathComponent("sleep-individual-homes-v47.png")) {
            background.setFill(); NSRect(x: 0, y: 0, width: 1200, height: 720).fill()
            for (i, friend) in friends.enumerated() {
                let rect = NSRect(x: CGFloat(i%3)*400+20, y: CGFloat(1-i/3)*340+55, width: 360, height: 214)
                HomeArtwork.shared.draw(in: rect, style: .hachiware, occupants: [occupant(friend)], now: now.addingTimeInterval(2), time: 0.9)
                (friend.name+" · 실제 집 크기" as NSString).draw(at: NSPoint(x: rect.minX+80, y: rect.minY-24), withAttributes: text)
            }
        }
        png(width: 1280, height: 850, to: directory.appendingPathComponent("sleep-shared-homes-v47.png")) {
            background.setFill(); NSRect(x: 0, y: 0, width: 1280, height: 850).fill()
            for (i, style) in HomeStyle.allCases.enumerated() {
                let large = NSRect(x: CGFloat(i)*640+20, y: 420, width: 600, height: 357)
                let actual = NSRect(x: CGFloat(i)*640+140, y: 90, width: 360, height: 214)
                for rect in [large, actual] {
                    HomeArtwork.shared.draw(in: rect, style: style, occupants: Friend.developmentRoster.map(occupant), now: now.addingTimeInterval(2), time: 0.9)
                }
                (style.title+" · 8명 함께 / 아래는 실제 크기" as NSString)
                    .draw(at: NSPoint(x: CGFloat(i)*640+80, y: 40), withAttributes: text)
            }
        }
        print("Six sleeping characters, breathing loop and both shared-house layouts exported.")
    }
}
