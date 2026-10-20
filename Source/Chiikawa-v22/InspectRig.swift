import Foundation
import AppKit
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let source = NSBitmapImageRep(data: try Data(contentsOf: input))!
let w=source.pixelsWide, h=source.pixelsHigh
var seen=[Bool](repeating:false,count:w*h)
var mask=[Bool](repeating:false,count:w*h)
for y in 0..<h { for x in 0..<w { mask[y*w+x]=(source.colorAt(x:x,y:y)?.alphaComponent ?? 0)>0.5 } }
var components:[[String:Int]]=[]
for start in 0..<w*h where mask[start] && !seen[start] {
    var q=[start],i=0,x0=w,x1=0,y0=h,y1=0; seen[start]=true
    while i<q.count {
        let p=q[i];i+=1;let x=p%w,y=p/w
        x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)
        for (xx,yy) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] where xx>=0 && xx<w && yy>=0 && yy<h {
            let n=yy*w+xx
            if mask[n] && !seen[n] { seen[n]=true;q.append(n) }
        }
    }
    if q.count>300 { components.append(["x":x0,"y":y0,"width":x1-x0+1,"height":y1-y0+1,"pixels":q.count]) }
}
let result:[String:Any] = ["width":w,"height":h,"has_alpha":source.hasAlpha,"opaque_corner":source.colorAt(x:0,y:0)!.alphaComponent,"components":components]
print(String(data:try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
