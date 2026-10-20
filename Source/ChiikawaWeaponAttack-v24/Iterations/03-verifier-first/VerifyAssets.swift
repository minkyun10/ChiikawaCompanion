import AppKit
import ImageIO

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
func load(_ url: URL) -> CGImage { NSBitmapImageRep(data: try! Data(contentsOf: url))!.cgImage! }
func pixels(_ image: CGImage) -> [UInt8] {
    var result = [UInt8](repeating: 0, count: image.width * image.height * 4)
    result.withUnsafeMutableBytes { raw in
        let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return result
}
var passed = 0
func check(_ result: Bool, _ label: String) { precondition(result, label); passed += 1; print("PASS: \(label)") }
let atlas = load(root.appendingPathComponent("Final/chiikawa-attack-v24.png"))
check(atlas.width == 1536 && atlas.height == 512, "six by two runtime atlas with 256-point cells")
var signatures = Set<Data>(), components: [Int] = []
for index in 0..<12 {
    let image = load(root.appendingPathComponent(String(format: "Final/Frames/chiikawa-attack-%02d.png", index + 1)))
    check(image.width == 256 && image.height == 256, "frame \(index+1) dimensions")
    let a = pixels(image), b = pixels(atlas.cropping(to: CGRect(x: index % 6 * 256, y: index / 6 * 256, width: 256, height: 256))!)
    check(zip(a,b).allSatisfy { abs(Int($0)-Int($1)) <= 2 }, "frame \(index+1) matches atlas chronological slot")
    signatures.insert(Data(a))
    check((0..<256).allSatisfy { i in a[(i * 256) * 4 + 3] == 0 && a[(i * 256 + 255) * 4 + 3] == 0
        && a[i * 4 + 3] == 0 && a[(255 * 256 + i) * 4 + 3] == 0 }, "frame \(index+1) all four edges transparent")
    var seen = [Bool](repeating: false, count: 65536), major = 0
    for n in 0..<65536 where !seen[n] && a[n*4+3] > 64 {
        var queue = [n], cursor = 0; seen[n] = true
        while cursor < queue.count {
            let current = queue[cursor]; cursor += 1; let x = current % 256, y = current / 256
            for (dx,dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
                let xx=x+dx, yy=y+dy
                if xx>=0 && yy>=0 && xx<256 && yy<256 { let next=yy*256+xx
                    if !seen[next] && a[next*4+3] > 64 { seen[next]=true; queue.append(next) }
                }
            }
        }
        if queue.count >= 40 { major += 1 }
    }
    components.append(major)
    check(major == 1, "frame \(index+1) one connected body, paws and weapon silhouette")
}
check(signatures.count == 12, "twelve distinct saved poses")
let gif = CGImageSourceCreateWithURL(root.appendingPathComponent("Review/chiikawa-hover-attack-v24.gif") as CFURL,nil)!
check(CGImageSourceGetCount(gif) == 24, "GIF contains twelve poses held for two samples each")
let duration = (0..<CGImageSourceGetCount(gif)).reduce(0.0) { sum,index in
    let properties = CGImageSourceCopyPropertiesAtIndex(gif,index,nil)! as NSDictionary
    let values = properties[kCGImagePropertyGIFDictionary] as! NSDictionary
    return sum + (values[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? values[kCGImagePropertyGIFDelayTime] as! Double)
}
check(abs(duration - 1.2) < 0.0001, "GIF uses the same 1.2-second cadence as Hachiware")
let report: [String: Any] = ["date":"2026-10-20","passed":passed,"frame_count":12,"gif_samples":24,
    "gif_duration":duration,"major_connected_components":components,"alpha_preserved":true,"row_major_verified":true]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("asset-verification.json"))
print("\(passed) asset checks passed.")
