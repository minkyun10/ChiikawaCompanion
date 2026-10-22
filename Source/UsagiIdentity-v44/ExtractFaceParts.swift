import AppKit
import CryptoKit

let args = CommandLine.arguments
precondition(args.count == 4, "ExtractFaceParts <sheet> <archive> <resources>")
let input = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: args[1])))!
let source = input.cgImage!, cellW = source.width / 3, cellH = source.height / 2
let archive = URL(fileURLWithPath: args[2]), resources = URL(fileURLWithPath: args[3])
try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
let names = ["neutral", "cheer", "shout", "curious", "sleep", "blink"]
var records: [[String: Any]] = []
for (index, name) in names.enumerated() {
    let cell = CGRect(x: index % 3 * cellW, y: index / 3 * cellH, width: cellW, height: cellH)
    let crop = source.cropping(to: cell)!, rep = NSBitmapImageRep(cgImage: crop)
    var opaque = [Bool](repeating: false, count: cellW * cellH), visited = opaque
    for y in 0..<cellH { for x in 0..<cellW {
        opaque[y * cellW + x] = (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5
    }}
    var components: [(Int, CGRect)] = []
    for start in opaque.indices where opaque[start] && !visited[start] {
        var queue = [start], i = 0, bounds = CGRect.null; visited[start] = true
        while i < queue.count {
            let n = queue[i]; i += 1; let x = n % cellW, y = n / cellW
            bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
            for (xx, yy) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] where xx >= 0 && xx < cellW && yy >= 0 && yy < cellH {
                let next = yy * cellW + xx
                if opaque[next] && !visited[next] { visited[next] = true; queue.append(next) }
            }
        }
        if queue.count > 80 { components.append((queue.count,bounds)) }
    }
    // The three largest connected ink pieces are the two eyes and joined muzzle.
    let parts = components.sorted { $0.0 > $1.0 }.prefix(3).map(\.1).sorted { $0.midY < $1.midY }
    precondition(parts.count == 3, "Expected only eyes and mouth in \(name)")
    let eyes = Array(parts.prefix(2)).sorted { $0.midX < $1.midX }
    let selected = [("mouth",parts[2]),("left-eye",eyes[0]),("right-eye",eyes[1])]
    for (part,bounds) in selected {
        let rect = bounds.insetBy(dx: -2, dy: -2).intersection(CGRect(x: 0,y: 0,width: cellW,height: cellH)).integral
        let png = NSBitmapImageRep(cgImage: crop.cropping(to: rect)!).representation(using: .png,properties: [:])!
        let filename = "usagi-face-\(name)-\(part)-v44.png"
        try png.write(to: archive.appendingPathComponent(filename))
        let applied = part == "mouth" && ["cheer","shout","curious","sleep"].contains(name)
            || part != "mouth" && ["sleep","blink"].contains(name)
        if applied { try png.write(to: resources.appendingPathComponent(filename)) }
        records.append(["file":filename,"cell":[cell.minX,cell.minY,cell.width,cell.height],
            "crop":[rect.minX,rect.minY,rect.width,rect.height],"runtime":applied,
            "sha256":SHA256.hash(data:png).map{String(format:"%02x",$0)}.joined()])
    }
}
try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted,.sortedKeys]).write(to: archive.appendingPathComponent("registration.json"))
print("Extracted 18 transparent parts; 8 runtime parts. Approved open eyes and brows stay original.")
