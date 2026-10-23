import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func renderMonster(to path: String) {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath:path,isDirectory:true), art = HachiwareMonsterSprites.shared
        guard art.isReady else { fputs("Missing monster rig or animation frames\n",stderr); exit(1) }
        try! FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        func atlas(_ frames: [NSImage], _ name: String) {
            let cell = frames[0].size, rows = frames.count/6
            png(width:Int(cell.width)*6,height:Int(cell.height)*rows,to:root.appendingPathComponent(name+".png")) {
                for (index, frame) in frames.enumerated() {
                    frame.draw(in:NSRect(x:CGFloat(index%6)*cell.width,y:CGFloat(rows-1-index/6)*cell.height,width:cell.width,height:cell.height))
                }
            }
        }
        for direction in ChiikawaDirection.allCases { atlas(art.walks[direction]!,"walk-\(direction.rawValue)-24") }
        for action in HachiwareAction.allCases { atlas(art.actions[action]!,"action-\(action.rawValue)-12") }
        atlas(art.sleeping,"sleep-12")
        func walkingPreview(_ index: Int) -> NSBitmapImageRep {
            RosterNativeRig.bitmap(NSSize(width:1024,height:576)) {
                NSColor(hex:0xF7F4EB).setFill(); NSRect(x:0,y:0,width:1024,height:576).fill()
                for (n, direction) in ChiikawaDirection.allCases.enumerated() {
                    let rect = NSRect(x:CGFloat(n%4)*256,y:CGFloat(1-n/4)*288+24,width:256,height:256)
                    art.walks[direction]![index].draw(in:rect)
                    (direction.rawValue as NSString).draw(at:NSPoint(x:rect.minX+80,y:rect.minY-12),
                        withAttributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.darkGray])
                }
            }
        }
        func actionsPreview(_ index: Int) -> NSBitmapImageRep {
            RosterNativeRig.bitmap(NSSize(width:1024,height:864)) {
                NSColor(hex:0xF7F4EB).setFill(); NSRect(x:0,y:0,width:1024,height:864).fill()
                for (n, action) in HachiwareAction.allCases.enumerated() {
                    let rect = NSRect(x:CGFloat(n%4)*256,y:CGFloat(2-n/4)*288+24,width:256,height:256)
                    if action == .attack {
                        let c = NSGraphicsContext.current!.cgContext; c.saveGState(); c.clip(to:rect)
                        art.draw(in:rect,time:Double(index)/12*1.2,action:.attack); c.restoreGState()
                    } else { art.actions[action]![index].draw(in:rect) }
                    (action.title as NSString).draw(at:NSPoint(x:rect.minX+85,y:rect.minY-12),
                        withAttributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.darkGray])
                }
                art.drawSleep(in:NSRect(x:768,y:44,width:256,height:220),time:Double(index)/12*3.6)
                ("잠자기" as NSString).draw(at:NSPoint(x:860,y:12),withAttributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.darkGray])
            }
        }
        func animation(_ name: String, count: Int, delay: Double, frame: (Int)->NSBitmapImageRep) {
            let gif = CGImageDestinationCreateWithURL(root.appendingPathComponent(name+".gif") as CFURL,UTType.gif.identifier as CFString,count,nil)!
            CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for n in 0..<count { CGImageDestinationAddImage(gif,frame(n).cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:delay]] as CFDictionary) }
            precondition(CGImageDestinationFinalize(gif))
        }
        try! walkingPreview(3).representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("eight-directions.png"))
        try! actionsPreview(3).representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("actions.png"))
        animation("eight-directions",count:24,delay:RoamingMotion.previewCycleDuration/24,frame:walkingPreview)
        animation("actions",count:12,delay:0.1,frame:actionsPreview)
        animation("transformation",count:36,delay:0.05) { index in
            RosterNativeRig.bitmap(NSSize(width:520,height:370)) {
                NSColor(hex:0xF7F4EB).setFill(); NSRect(x:0,y:0,width:520,height:370).fill()
                let progress = CGFloat(min(1,max(0,(Double(index)-8)/13))), rect = NSRect(x:110,y:36,width:300,height:300)
                let c = NSGraphicsContext.current!.cgContext
                c.saveGState(); c.setAlpha(1-progress); FriendArtwork.draw(.hachiware,in:rect); c.restoreGState()
                c.saveGState(); c.setAlpha(progress); art.draw(in:rect,time:0); c.restoreGState()
                ("10초 안에 5번 클릭 → 변신" as NSString).draw(at:NSPoint(x:150,y:10),withAttributes:[.font:NSFont.systemFont(ofSize:16),.foregroundColor:NSColor.darkGray])
            }
        }
        print("Monster: 8 × 24 walk frames, 11 × 12 actions, 12 sleep frames and review animations exported.")
    }
}
