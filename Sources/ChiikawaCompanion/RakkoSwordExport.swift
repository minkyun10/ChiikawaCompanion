import AppKit
import ImageIO
import UniformTypeIdentifiers

extension SelfTest {
    static func renderRakkoSword(to path: String) {
        let root=URL(fileURLWithPath:path,isDirectory:true), art=RosterSprites.shared(.rakko)
        precondition(art.isReady)
        try! FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        func image(_ name:String,size:NSSize,draw:()->Void) {
            try! RosterNativeRig.bitmap(size,draw:draw).representation(using:.png,properties:[:])!
                .write(to:root.appendingPathComponent(name+".png"))
        }
        image("sheathed-item",size:NSSize(width:120,height:200)) {
            RakkoSwordArtwork.sheathed(in:NSRect(x:40,y:12,width:44,height:176))
        }
        image("sword-details",size:NSSize(width:740,height:270)) {
            NSColor(hex:0xF7F4EB).setFill();NSRect(x:0,y:0,width:740,height:270).fill()
            RakkoSwordArtwork.sheathed(in:NSRect(x:55,y:35,width:47,height:188))
            RakkoSwordArtwork.blade(grip:NSPoint(x:650,y:125),angle:0,scale:2.8)
        }
        image("attack-12",size:NSSize(width:2640,height:512)) {
            for n in 0..<12 { art.actions[.attack]![n].draw(in:NSRect(x:CGFloat(n%6)*440,y:CGFloat(1-n/6)*256,width:440,height:256)) }
        }
        image("armed-eight-directions",size:NSSize(width:1024,height:576)) {
            NSColor(hex:0xF7F4EB).setFill();NSRect(x:0,y:0,width:1024,height:576).fill()
            for (index,direction) in ChiikawaDirection.allCases.enumerated() {
                let facing:CGFloat=[ChiikawaDirection.right,.upRight,.downRight].contains(direction) ? 1:-1
                let pose:HachiwarePose=direction == .up ? .back : direction == .down ? .front
                    : [ChiikawaDirection.left,.right].contains(direction) ? .side
                    : [ChiikawaDirection.upLeft,.upRight].contains(direction) ? .backDiagonal:.frontDiagonal
                let rect=NSRect(x:CGFloat(index%4)*256,y:CGFloat(1-index/4)*288+24,width:256,height:256)
                FriendArtwork.draw(.rakko,in:rect,walking:true,facing:facing,walkPhase:0.3,pose:pose,rosterVisual:RosterVisual(equipped:.weapon))
                (direction.rawValue as NSString).draw(at:NSPoint(x:rect.minX+84,y:rect.minY-12),
                    withAttributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.darkGray])
            }
        }
        let gif=CGImageDestinationCreateWithURL(root.appendingPathComponent("attack.gif") as CFURL,UTType.gif.identifier as CFString,12,nil)!
        CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for index in 0..<12 {
            let frame=RosterNativeRig.bitmap(NSSize(width:500,height:300)) {
                NSColor(hex:0xF7F4EB).setFill();NSRect(x:0,y:0,width:500,height:300).fill()
                let body=NSRect(x:160,y:14,width:256,height:256)
                art.draw(action:.attack,in:body,elapsed:(Double(index)+0.1)*0.1)
                ("RAKKO · 검과 칼집" as NSString).draw(at:NSPoint(x:184,y:276),
                    withAttributes:[.font:NSFont.systemFont(ofSize:16),.foregroundColor:NSColor.darkGray])
            }
            if index == 3 { try! frame.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("attack-preview.png")) }
            CGImageDestinationAddImage(gif,frame.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(gif))
        print("Rakko sword, scabbard, eight armed directions and twelve swing frames exported.")
    }
}
