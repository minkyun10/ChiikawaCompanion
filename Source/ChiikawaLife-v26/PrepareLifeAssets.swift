import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let final = root.appendingPathComponent("Final", isDirectory: true)
try FileManager.default.createDirectory(at: final, withIntermediateDirectories: true)
func load(_ file: String) throws -> CGImage {
    NSBitmapImageRep(data: try Data(contentsOf: root.appendingPathComponent(file)))!.cgImage!
}
func bounds(_ image: CGImage) -> CGRect {
    let rep = NSBitmapImageRep(cgImage: image)
    var result = CGRect.null
    for y in 0..<image.height { for x in 0..<image.width where (rep.colorAt(x: x,y: y)?.alphaComponent ?? 0) > 0.12 {
        result = result.union(CGRect(x: x,y: y,width: 1,height: 1))
    } }
    precondition(!result.isNull)
    return result
}
func save(_ image: CGImage, _ name: String) throws {
    let cropped = image.cropping(to: bounds(image))!
    try NSBitmapImageRep(cgImage: cropped).representation(using: .png,properties: [:])!
        .write(to: final.appendingPathComponent(name+".png"))
}
func gap(_ expected: Int, radius: Int, limit: Int, quiet: (Int)->Bool) -> Int {
    let lo = max(1,expected-radius), hi = min(limit-1,expected+radius)
    var runs: [(Int,Int)] = [], begin: Int?
    for n in lo..<hi {
        if quiet(n) { if begin == nil { begin = n } }
        else if let start = begin { runs.append((start,n-1)); begin = nil }
    }
    if let begin { runs.append((begin,hi-1)) }
    guard let run = runs.max(by: { $0.1-$0.0 < $1.1-$1.0 }) else { fatalError("Missing transparent gutter near \(expected)") }
    return (run.0+run.1)/2
}
try save(load("Generated/house-original-v1.png"),"chiikawa-house-v26")
let source = try load("Generated/poses-original-v1.png"), rep = NSBitmapImageRep(cgImage: source)
let row = gap(source.height/2,radius: source.height/8,limit: source.height) { y in
    (0..<source.width).allSatisfy { (rep.colorAt(x: $0,y: y)?.alphaComponent ?? 0) < 0.06 }
}
let rows = [0,row,source.height]
let names = ["sleep","pajamas","hug","startled","determined","gentle"]
var report: [[String: Any]] = []
for r in 0..<2 {
    let edges = [0]+[1,2].map { c in
        gap(source.width*c/3,radius: source.width/7,limit: source.width) { x in
            (rows[r]..<rows[r+1]).allSatisfy { (rep.colorAt(x: x,y: $0)?.alphaComponent ?? 0) < 0.06 }
        }
    }+[source.width]
    for c in 0..<3 {
        // Keep the transparent gutter pixel in both neighboring crops. The
        // first futon ends immediately before a one-pixel transparent gap.
        let right = min(source.width,edges[c+1]+(c < 2 ? 1 : 0))
        let bottom = min(source.height,rows[r+1]+(r == 0 ? 1 : 0))
        let rect = CGRect(x: edges[c],y: rows[r],width: right-edges[c],height: bottom-rows[r])
        let cut = source.cropping(to: rect)!, b = bounds(cut), name = names[r*3+c]
        precondition(b.minX > 0 && b.minY > 0 && b.maxX < CGFloat(cut.width) && b.maxY < CGFloat(cut.height),"Clipped pose \(name)")
        try save(cut,"chiikawa-\(name)-v26")
        report.append(["name":name,"source_rect":[rect.minX,rect.minY,rect.width,rect.height],"alpha_bounds":[b.minX,b.minY,b.width,b.height]])
    }
}
try JSONSerialization.data(withJSONObject: ["source_size":[source.width,source.height],"poses":report],options: [.prettyPrinted,.sortedKeys])
    .write(to: final.appendingPathComponent("pose-registration.json"))
print("Registered empty house, sleeping/pajama/hug cutouts and three new reactions; native alpha preserved.")
