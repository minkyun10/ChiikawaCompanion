import AppKit
import Foundation
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let records = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("references.json"))) as! [String: Any]
let refs = (records["sources"] as! [[String: Any]]).filter { ($0["role"] as! String).contains("Decorative") == false }
let w=1600, h=1150
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide:w, pixelsHigh:h, bitsPerSample:8,
    samplesPerPixel:4, hasAlpha:true, isPlanar:false, colorSpaceName:.deviceRGB, bytesPerRow:w*4, bitsPerPixel:32)!
let context = NSGraphicsContext(bitmapImageRep:rep)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context
context.imageInterpolation = .high
NSColor(srgbRed:0.98,green:0.97,blue:0.95,alpha:1).setFill();NSRect(x:0,y:0,width:w,height:h).fill()
func text(_ s:String,_ r:NSRect,_ size:CGFloat=16) {
    let p=NSMutableParagraphStyle();p.alignment = .center
    (s as NSString).draw(in:r,withAttributes:[.font:NSFont.systemFont(ofSize:size),.foregroundColor:NSColor.darkGray,.paragraphStyle:p])
}
text("CHIIKAWA · COLLECTED OFFICIAL REFERENCES",NSRect(x:0,y:1090,width:1600,height:40),28)
text("2026-10-20 · 2D anatomy / expression and equipment references",NSRect(x:0,y:1055,width:1600,height:26),17)
for (i,ref) in refs.enumerated() {
    let x=CGFloat(i%4)*390+25,y=CGFloat(1-i/4)*480+75
    NSColor.white.setFill();NSBezierPath(roundedRect:NSRect(x:x,y:y,width:375,height:458),xRadius:18,yRadius:18).fill()
    let image=NSImage(contentsOf:root.appendingPathComponent(ref["path"] as! String))!
    let scale=min(335/image.size.width,355/image.size.height)
    image.draw(in:NSRect(x:x+(375-image.size.width*scale)/2,y:y+75+(355-image.size.height*scale)/2,
                        width:image.size.width*scale,height:image.size.height*scale))
    text(i == 0 ? "ANIME · 2D IDENTITY" : "OFFICIAL FIGURE · \(i)",NSRect(x:x+5,y:y+35,width:365,height:28),17)
    text(i == 0 ? "Round ears / face / proportions" : "Expression / pochette / sasumata",NSRect(x:x+5,y:y+10,width:365,height:23),13)
}
text("Source URLs, original files and SHA-256 hashes: references.json",NSRect(x:0,y:20,width:1600,height:28),16)
context.flushGraphics();NSGraphicsContext.restoreGraphicsState()
try rep.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("Review/chiikawa-collected-references-v22.png"))
print("Seven usable official reference images composed into the review board; decorative background retained separately.")
