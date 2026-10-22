import AppKit
import ImageIO
import UniformTypeIdentifiers

let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let output=root.appendingPathComponent("Source/NewFriends-v45/Final")
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let friends=[("rakko","랏코 · 딸기 파르페"),("shisa","시사 · 라멘"),("kani","카니 · 헌책")]
var images:[String:NSImage]=[:]
for (slug,_) in friends {
    images[slug+"-tpose"]=NSImage(contentsOf:root.appendingPathComponent("Source/NewFriends-v45/Parts/\(slug)/\(slug)-rig-t-pose-v38.png"))!
    for (name,count,height) in [("down-left-24",24,256),("laugh-12",12,256),("keepsake-12",12,256),("sleep-12",12,180)] {
        let data=try Data(contentsOf:root.appendingPathComponent("build/roster/\(slug)/\(name).png"))
        let source=NSBitmapImageRep(data:data)!.cgImage!
        for n in 0..<count {
            let crop=source.cropping(to:CGRect(x:n%6*256,y:n/6*height,width:256,height:height))!
            images[slug+"-"+name+"-\(n)"]=NSImage(cgImage:crop,size:NSSize(width:256,height:height))
        }
    }
}
func fitted(_ image:NSImage,_ rect:NSRect) {
    let scale=min(rect.width/image.size.width,rect.height/image.size.height)
    image.draw(in:NSRect(x:rect.midX-image.size.width*scale/2,y:rect.midY-image.size.height*scale/2,width:image.size.width*scale,height:image.size.height*scale))
}
func frame(_ n:Int)->NSBitmapImageRep {
    let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:960,pixelsHigh:1040,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:3840,bitsPerPixel:32)!
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
    NSColor(srgbRed:0.98,green:0.97,blue:0.94,alpha:1).setFill();NSRect(x:0,y:0,width:960,height:1040).fill()
    for (column,entry) in friends.enumerated() {
        let (slug,title)=entry,x=CGFloat(column)*320
        (title as NSString).draw(at:NSPoint(x:x+55,y:1006),withAttributes:[.font:NSFont.systemFont(ofSize:19,weight:.semibold),.foregroundColor:NSColor.darkGray])
        for row in 0..<5 {
            let names=["T-pose","24프레임 걷기","호버 · 웃음","전용 소품 동작","공용 집 수면"]
            let key:String
            switch row {
            case 0:key=slug+"-tpose"
            case 1:key=slug+"-down-left-24-\(n%24)"
            case 2:key=slug+"-laugh-12-\((n/2)%12)"
            case 3:key=slug+"-keepsake-12-\((n/2)%12)"
            default:key=slug+"-sleep-12-\((n/2)%12)"
            }
            let y=CGFloat(4-row)*198+16
            fitted(images[key]!,NSRect(x:x+66,y:y+20,width:188,height:174))
            (names[row] as NSString).draw(at:NSPoint(x:x+98,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor.darkGray])
        }
    }
    NSGraphicsContext.restoreGraphicsState();return rep
}
try frame(6).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("character-preview.png"))
let gif=CGImageDestinationCreateWithURL(output.appendingPathComponent("character-motion.gif") as CFURL,UTType.gif.identifier as CFString,48,nil)!
CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
for n in 0..<48 { CGImageDestinationAddImage(gif,frame(n).cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary) }
precondition(CGImageDestinationFinalize(gif))
print("Combined T-pose, walk, reaction, item and sleep preview saved.")
