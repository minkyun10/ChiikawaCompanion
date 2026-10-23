import AppKit
import CryptoKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let resources = URL(fileURLWithPath: CommandLine.arguments[2])
let source = NSBitmapImageRep(data: try Data(contentsOf: root.appendingPathComponent("Generated/monster-rig-atlas-v53.png")))!.cgImage!
let output = root.appendingPathComponent("Rig")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let xs = [0, 418, 748, 1138, 1536], ys = [0, 551, 1024]
let names = ["front", "side", "back", "front-diagonal", "back-diagonal", "arm", "foot", "tail"]
var records: [[String: Any]] = []
for (index, name) in names.enumerated() {
    let cell = CGRect(x: xs[index%4], y: ys[index/4], width: xs[index%4+1]-xs[index%4], height: ys[index/4+1]-ys[index/4])
    let crop = source.cropping(to: cell)!, pixels = NSBitmapImageRep(cgImage: source.cropping(to: cell)!)
    var bounds = CGRect.null
    for y in 0..<crop.height { for x in 0..<crop.width where (pixels.colorAt(x:x,y:y)?.alphaComponent ?? 0) > 0.25 {
        bounds = bounds.union(CGRect(x:x,y:y,width:1,height:1))
    } }
    precondition(!bounds.isNull && bounds.width > 40 && bounds.height > 100)
    let trim = bounds.insetBy(dx:-2,dy:-2).intersection(CGRect(x:0,y:0,width:crop.width,height:crop.height)).integral
    let image = crop.cropping(to:trim)!
    let data = NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!
    let filename = "hachiware-monster-rig-\(name)-v53.png"
    try data.write(to:output.appendingPathComponent(filename))
    try data.write(to:resources.appendingPathComponent(filename))
    records.append(["name":name,"cell":[cell.minX,cell.minY,cell.width,cell.height],"trim":[trim.minX,trim.minY,trim.width,trim.height],"sha256":SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()])
}
try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("registration.json"))
print("Extracted eight approved monster animation components.")
