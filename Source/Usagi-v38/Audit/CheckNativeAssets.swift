import AppKit
import Foundation
let root=URL(fileURLWithPath:CommandLine.arguments[1]), height=Int(CommandLine.arguments[2])!
let mouthLow=CommandLine.arguments.count>3 ? Int(CommandLine.arguments[3])! : 120
let mouthHigh=CommandLine.arguments.count>4 ? Int(CommandLine.arguments[4])! : 175
var checks=0
func check(_ ok:Bool,_ text:String) {guard ok else {fputs("FAIL: \(text)\n",stderr);exit(1)};checks+=1;print("PASS: \(text)")}
for direction in ["down","up","left","right","down-left","down-right","up-left","up-right"] {
    let rep=NSBitmapImageRep(data:try Data(contentsOf:root.appendingPathComponent("\(direction)-24.png")))!
    check(rep.pixelsWide==1536 && rep.pixelsHigh==height*4,"\(direction) atlas contains the complete six-column four-row cycle")
    for frame in 0..<24 {
        let xx=frame%6*256, yy=frame/6*height
        var bounds=NSRect.null
        for y in 0..<height {for x in 0..<256 where (rep.colorAt(x:xx+x,y:yy+y)?.alphaComponent ?? 0)>0.25 {
            bounds=bounds.union(NSRect(x:x,y:y,width:1,height:1))
        }}
        check(!bounds.isNull && bounds.minX>2 && bounds.maxX<254 && bounds.minY>2 && bounds.maxY<CGFloat(height-2),
              "\(direction) frame \(frame+1) has opaque artwork with unclipped ears, hands and feet")
    }
}
let study=NSBitmapImageRep(data:try Data(contentsOf:root.appendingPathComponent("study-12.png")))!
for frame in 0..<12 {
    let xx=frame%6*256, yy=frame/6*height
    var pink=0
    for y in (height-mouthHigh)..<(height-mouthLow) {for x in 117..<141 {
        guard let c=study.colorAt(x:xx+x,y:yy+y)?.usingColorSpace(.deviceRGB) else {continue}
        if c.alphaComponent>0.8 && c.redComponent>0.8 && c.redComponent-c.greenComponent>0.12 && c.blueComponent>0.55 {pink+=1}
    }}
    check(pink>=3,"study frame \(frame+1) preserves a visible pink tongue in the central mouth region")
}
print("\(checks) exported native asset checks passed.")
