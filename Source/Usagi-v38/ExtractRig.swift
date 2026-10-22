import AppKit
import CryptoKit
let args = CommandLine.arguments
precondition(args.count == 5, "ExtractRig <source.png> <friend-slug> <source-output> <resources-output>")
let bitmap = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: args[1])))!
let source = bitmap.cgImage!, w = source.width, h = source.height
let sourceOutput = URL(fileURLWithPath: args[3]), resources = URL(fileURLWithPath: args[4])
try FileManager.default.createDirectory(at: sourceOutput,withIntermediateDirectories: true)
let edges = [0,Int(Double(h)*0.355),Int(Double(h)*0.71),h]
let selections = [(0,"front"),(1,"side"),(2,"back"),(3,"front-diagonal"),(4,"back-diagonal"),(5,"t-pose"),(6,"arm"),(7,"foot"),(8,"top")]
var records: [[String: Any]] = []
for (index,name) in selections {
    let x0 = index%3*w/3, x1 = (index%3+1)*w/3, y0 = edges[index/3], y1 = edges[index/3+1]
    let crop = source.cropping(to: CGRect(x:x0,y:y0,width:x1-x0,height:y1-y0))!
    let rep = NSBitmapImageRep(cgImage:crop), width = crop.width, height = crop.height
    var visited = [Bool](repeating:false,count:width*height), opaque = visited
    for y in 0..<height { for x in 0..<width { opaque[y*width+x] = (rep.colorAt(x:x,y:y)?.alphaComponent ?? 0)>0.25 } }
    var chosen = CGRect.null, biggest = 0
    for start in 0..<opaque.count where opaque[start] && !visited[start] {
        var queue=[start], i=0, bounds=CGRect.null;visited[start]=true
        while i<queue.count {
            let n=queue[i];i+=1;let x=n%width,y=n/width
            bounds=bounds.union(CGRect(x:x,y:y,width:1,height:1))
            for (xx,yy) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] where xx>=0 && xx<width && yy>=0 && yy<height {
                let next=yy*width+xx
                if opaque[next] && !visited[next] {visited[next]=true;queue.append(next)}
            }
        }
        if queue.count>biggest {biggest=queue.count;chosen=bounds}
    }
    precondition(biggest>100)
    let bounds=chosen.insetBy(dx:-3,dy:-3).intersection(CGRect(x:0,y:0,width:width,height:height)).integral
    let trimmed=crop.cropping(to:bounds)!
    let data=NSBitmapImageRep(cgImage:trimmed).representation(using:.png,properties:[:])!
    let filename="\(args[2])-rig-\(name)-v38.png"
    try data.write(to:sourceOutput.appendingPathComponent(filename))
    if name != "t-pose" && name != "top" {try data.write(to:resources.appendingPathComponent(filename))}
    records.append(["name":name,"sourceCell":[x0,y0,x1-x0,y1-y0],"trim":[bounds.minX,bounds.minY,bounds.width,bounds.height],"sha256":SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()])
}
try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:sourceOutput.appendingPathComponent("rig-registration.json"))
print("Extracted nine isolated source cells; seven runtime rig parts.")
