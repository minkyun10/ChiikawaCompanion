import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func renderRoster(to path: String) {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: path, isDirectory: true)
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for friend in Friend.developmentRoster where friend.isExpansion {
            let art = RosterSprites.shared(friend)
            guard art.isReady else { fputs("Missing rig for \(friend.rawValue)\n", stderr); exit(1) }
            let dir = root.appendingPathComponent(friend.rawValue, isDirectory: true)
            try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let canvas = friend.canvasSize
            for direction in ChiikawaDirection.allCases {
                let frames = art.walks[direction]!
                png(width: Int(canvas.width)*6, height: Int(canvas.height)*4,
                    to: dir.appendingPathComponent("\(direction.rawValue)-24.png")) {
                    for (n, frame) in frames.enumerated() {
                        frame.draw(in: NSRect(x: CGFloat(n%6)*canvas.width, y: CGFloat(3-n/6)*canvas.height, width: canvas.width, height: canvas.height))
                    }
                }
            }
            for action in RosterAction.available(for: friend) {
                let frames = art.actions[action]!, size = frames[0].size
                png(width: Int(size.width)*6, height: Int(size.height)*2,
                    to: dir.appendingPathComponent("\(action.rawValue)-12.png")) {
                    for (n, frame) in frames.enumerated() {
                        frame.draw(in: NSRect(x: CGFloat(n%6)*size.width, y: CGFloat(1-n/6)*size.height, width: size.width, height: size.height))
                    }
                }
            }
            let cell = NSSize(width: 230, height: friend == .usagi ? 330 : 260)
            func preview(_ frame: Int) -> NSBitmapImageRep {
                RosterNativeRig.bitmap(NSSize(width: cell.width*4,height: cell.height*2)) {
                    NSColor(hex: 0xF7F4EB).setFill(); NSRect(x: 0,y: 0,width: cell.width*4,height: cell.height*2).fill()
                    for (n, direction) in ChiikawaDirection.allCases.enumerated() {
                        let rect = NSRect(x: CGFloat(n%4)*cell.width+15,y: CGFloat(1-n/4)*cell.height+28,width: cell.width-30,height: cell.height-40)
                        art.walks[direction]![frame].draw(in: rect)
                        (direction.rawValue as NSString).draw(at: NSPoint(x: rect.minX+45,y: rect.minY-18),withAttributes: [.font:NSFont.systemFont(ofSize:14),.foregroundColor:NSColor.darkGray])
                    }
                }
            }
            let first = preview(0)
            try! first.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("eight-directions.png"))
            let gif = CGImageDestinationCreateWithURL(dir.appendingPathComponent("eight-directions.gif") as CFURL, UTType.gif.identifier as CFString, 24, nil)!
            CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for n in 0..<24 {
                CGImageDestinationAddImage(gif, preview(n).cgImage!, [kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:RoamingMotion.previewCycleDuration/24]] as CFDictionary)
            }
            precondition(CGImageDestinationFinalize(gif))
            png(width: 1024,height: Int(cell.height)*4,to: dir.appendingPathComponent("actions-preview.png")) {
                NSColor(hex:0xF7F4EB).setFill();NSRect(x:0,y:0,width:1024,height:cell.height*4).fill()
                for (n, action) in RosterAction.available(for: friend).enumerated() {
                    let rect=NSRect(x:CGFloat(n%4)*256+10,y:CGFloat(3-n/4)*cell.height+25,width:236,height:cell.height-35)
                    art.draw(action:action,in:rect,elapsed:action.cycle*0.25)
                    (action.title as NSString).draw(at:NSPoint(x:rect.minX+50,y:rect.minY-17),withAttributes:[.font:NSFont.systemFont(ofSize:14),.foregroundColor:NSColor.darkGray])
                }
            }
        }
        print("Native roster sheets and cycle previews exported.")
    }
}
