// Read-only verification of exported PNGs and GIFs, independent of the renderer's clock.
import Foundation
import ImageIO
import CoreGraphics
let root=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
var checks=0
func check(_ value:Bool,_ message:String) {
    if !value { fputs("FAIL: \(message)\n",stderr);exit(1) }
    checks += 1
}
func image(_ url:URL)->CGImage {
    guard let source=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else { fatalError("Cannot decode \(url.lastPathComponent)") }
    return image
}
func rgba(_ image:CGImage)->[UInt8] {
    var data=[UInt8](repeating:0,count:image.width*image.height*4)
    data.withUnsafeMutableBytes { bytes in
        let c=CGContext(data:bytes.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,
            bytesPerRow:image.width*4,space:CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
    }
    return data
}
func closePixels(_ a:[UInt8],_ b:[UInt8],tolerance:Int=2)->Bool {
    a.count == b.count && zip(a,b).allSatisfy { abs(Int($0)-Int($1))<=tolerance }
}
let names=["left","right","down","up","down-left","down-right","up-left","up-right"]
var decoded:[String:[[UInt8]]]=[:]
var cgFrames:[String:[CGImage]]=[:]
for name in names {
    let atlas=image(root.appendingPathComponent("Atlases/chiikawa-\(name)-24.png"))
    check(atlas.width == 1536 && atlas.height == 1024,"\(name) atlas dimensions")
    var images:[CGImage]=[],pixels:[[UInt8]]=[]
    for i in 0..<24 {
        let frame=image(root.appendingPathComponent(String(format:"Frames/%@-%02d.png",name,i+1)))
        check(frame.width == 256 && frame.height == 256,"\(name) frame \(i+1) dimensions")
        let data=rgba(frame)
        let crop=atlas.cropping(to:CGRect(x:(i%6)*256,y:(i/6)*256,width:256,height:256))!
        check(closePixels(data,rgba(crop)),"\(name) chronological atlas slot \(i+1)")
        check([3,255*4+3,255*1024+3,255*1024+255*4+3].allSatisfy { data[$0] == 0 },"\(name) four transparent corners \(i+1)")
        images.append(frame);pixels.append(data)
    }
    decoded[name]=pixels;cgFrames[name]=images
    for i in 0..<12 {
        let headA=rgba(images[i].cropping(to:CGRect(x:0,y:0,width:256,height:125))!)
        let headB=rgba(images[i+12].cropping(to:CGRect(x:0,y:0,width:256,height:125))!)
        check(closePixels(headA,headB,tolerance:1),"\(name) identity preserved in opposite step \(i+1)")
    }
}
for (left,right) in [("left","right"),("down-left","down-right"),("up-left","up-right")] {
    for frame in 0..<24 {
        let a=decoded[left]![frame],b=decoded[right]![frame]
        var exact=true
        for y in 0..<256 { for x in 0..<256 { for c in 0..<4 {
            if a[y*1024+x*4+c] != b[y*1024+(255-x)*4+c] { exact=false }
        } } }
        check(exact,"\(right) exact mirror of completed \(left) frame \(frame+1)")
    }
}
for (file,duration) in [("chiikawa-eight-direction-walk-v22.gif",1.36),("chiikawa-eight-direction-walk-slow-v22.gif",2.88)] {
    let source=CGImageSourceCreateWithURL(root.appendingPathComponent(file) as CFURL,nil)!
    check(CGImageSourceGetCount(source)==24,"\(file) 24 chronological frames")
    var sum=0.0
    for i in 0..<24 {
        let props=CGImageSourceCopyPropertiesAtIndex(source,i,nil)! as NSDictionary
        let gif=props[kCGImagePropertyGIFDictionary] as! NSDictionary
        sum += (gif[kCGImagePropertyGIFUnclampedDelayTime] ?? gif[kCGImagePropertyGIFDelayTime]) as! Double
    }
    check(abs(sum-duration)<0.0001,"\(file) complete cycle timing")
}
let metadata=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("validation.json"))) as! [String:Any]
check((metadata["left_right_half_cycle_max_error"] as! Double)<0.00001,"both feet share one path offset by half a cycle")
check((metadata["side_planted_foot_compensation_error"] as! Double)<0.00001,"side stance matches the declared travel distance")
let directions=metadata["directions"] as! [[String:Any]]
check(directions.allSatisfy { ($0["distinct_pixel_frames"] as! Int)==24 },"every direction contains 24 distinct drawings")
check(directions.allSatisfy { ($0["largest_component_counts"] as! [Int]).allSatisfy { $0 == 1 } },"all limbs join the character in every exported frame")
let result:[String:Any]=["checks_passed":checks,"direction_count":8,"individual_frames_checked":192,
    "atlas_layout":"6 columns x 4 rows; chronological row-major order","all_mirrors_pixel_exact":true,
    "png_round_trip_tolerance":2,"normal_gif_cycle_seconds":1.36,"slow_gif_cycle_seconds":2.88,
    "runtime_applied":false]
let report=root.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("asset-verification.json")
try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:report)
print("\(checks) checks passed for 8 directions, 192 frames, atlas order, identity, exact mirroring and GIF timing.")
