import AppKit

// Register/crop generated sprite pixels; preserve their native alpha. No background replacement.
let args = CommandLine.arguments
guard args.count == 6 else { fatalError("Usage: PrepareMotionAtlas <generated.png> <output-directory> <name> <columns> <rows>") }
let name = args[3], columns = Int(args[4])!, rows = Int(args[5])!, count = columns*rows
let source = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: args[1])))!.cgImage!
let output = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: output.appendingPathComponent("Frames"), withIntermediateDirectories: true)
struct Cell { let image: CGImage; let head: CGRect; let bounds: CGRect }
let full = NSBitmapImageRep(cgImage: source)
func gap(near expected: Int, radius: Int, limit: Int, quiet: (Int) -> Bool) -> Int {
    var runs: [(Int,Int)] = [], first: Int?
    let lo = max(1,expected-radius), hi = min(limit-1,expected+radius)
    for n in lo..<hi {
        if quiet(n) { if first == nil { first = n } }
        else if let start = first { runs.append((start,n-1)); first = nil }
    }
    if let first { runs.append((first,hi-1)) }
    guard let run = runs.max(by: { $0.1-$0.0 < $1.1-$1.0 }) else { fatalError("No transparent gutter near \(expected)") }
    return (run.0+run.1)/2
}
let rowEdges = [0] + (1..<rows).map { row in gap(near:source.height*row/rows,radius:source.height/(rows*4),limit:source.height) { y in
    (0..<source.width).allSatisfy { (full.colorAt(x:$0,y:y)?.alphaComponent ?? 0) < 0.04 }
} } + [source.height]
let columnEdges = (0..<rows).map { row in [0] + (1..<columns).map { col in
    gap(near:source.width*col/columns,radius:source.width/(columns*4),limit:source.width) { x in
        (rowEdges[row]..<rowEdges[row+1]).allSatisfy { (full.colorAt(x:x,y:$0)?.alphaComponent ?? 0) < 0.04 }
    }
} + [source.width] }
var cells: [Cell] = []
for index in 0..<count {
    let row = index/columns, col = index%columns, x0 = columnEdges[row][col], x1 = columnEdges[row][col+1]
    let y0 = rowEdges[row], y1 = rowEdges[row+1]
    let crop = source.cropping(to:CGRect(x:x0,y:y0,width:x1-x0,height:y1-y0))!
    let rep = NSBitmapImageRep(cgImage:crop), w = crop.width, h = crop.height
    var bounds = CGRect.null
    var white = [Bool](repeating:false,count:w*h)
    for y in 0..<h { for x in 0..<w {
        guard let c = rep.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB),c.alphaComponent > 0.25 else { continue }
        bounds = bounds.union(CGRect(x:x,y:y,width:1,height:1))
        white[y*w+x] = c.alphaComponent > 0.8 && min(c.redComponent,c.greenComponent,c.blueComponent) > 0.90
            && max(c.redComponent,c.greenComponent,c.blueComponent)-min(c.redComponent,c.greenComponent,c.blueComponent) < 0.07
    } }
    precondition(!bounds.isNull && bounds.minX > 1 && bounds.minY > 1 && bounds.maxX < CGFloat(w-1) && bounds.maxY < CGFloat(h-1), "Clipped sprite \(index+1)")
    // The largest connected white region is the face and torso above the pink table.
    // It excludes the notebook and tabletop, unlike full alpha bounds.
    var seen = [Bool](repeating:false,count:w*h), largest = CGRect.null, largestCount = 0
    for start in 0..<white.count where white[start] && !seen[start] {
        var queue = [start], cursor = 0, region = CGRect.null; seen[start] = true
        while cursor < queue.count {
            let n = queue[cursor]; cursor += 1; let x = n%w,y = n/w
            region = region.union(CGRect(x:x,y:y,width:1,height:1))
            for (dx,dy) in [(1,0),(-1,0),(0,1),(0,-1)] {
                let xx = x+dx, yy = y+dy
                if xx>=0 && yy>=0 && xx<w && yy<h { let nn = yy*w+xx
                    if white[nn] && !seen[nn] { seen[nn] = true; queue.append(nn) }
                }
            }
        }
        if queue.count > largestCount { largestCount = queue.count; largest = region }
    }
    precondition(largestCount > 100 && largest.width > 30,"Missing white character \(index+1)")
    cells.append(Cell(image:crop,head:largest,bounds:bounds))
}
let leftExtent = cells.map { ($0.head.midX-$0.bounds.minX)/$0.head.width }.max()!
let rightExtent = cells.map { ($0.bounds.maxX-$0.head.midX)/$0.head.width }.max()!
let heightExtent = cells.map { $0.bounds.height/$0.head.width }.max()!
let headWidth = min(168,232/(leftExtent+rightExtent),216/heightExtent)
let anchor = 12 + leftExtent*headWidth
func bitmap(_ width:Int,_ height:Int,draw:()->Void)->NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,
        samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:width*4,bitsPerPixel:32)!
    let context = NSGraphicsContext(bitmapImageRep:rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    context.imageInterpolation = .high; draw(); context.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
    return rep
}
var frames:[NSImage] = [], report:[[String:Any]] = []
for (index,cell) in cells.enumerated() {
    let scale = name == "rest" ? min(232/cells.map { $0.bounds.width }.max()!,216/cells.map { $0.bounds.height }.max()!) : headWidth/cell.head.width
    let rep = bitmap(256,256) {
        NSImage(cgImage:cell.image,size:NSSize(width:cell.image.width,height:cell.image.height)).draw(in:
            NSRect(x: name == "rest" ? 128-cell.bounds.midX*scale : anchor-cell.head.midX*scale,y:26-(CGFloat(cell.image.height)-cell.bounds.maxY)*scale,
                   width:CGFloat(cell.image.width)*scale,height:CGFloat(cell.image.height)*scale))
    }
    try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(String(format:"Frames/chiikawa-\(name)-%02d.png",index+1)))
    frames.append(NSImage(cgImage:rep.cgImage!,size:NSSize(width:256,height:256)))
    report.append(["frame":index+1,"scale":scale,"head_bounds":[cell.head.minX,cell.head.minY,cell.head.width,cell.head.height],
                   "source_bounds":[cell.bounds.minX,cell.bounds.minY,cell.bounds.width,cell.bounds.height]])
}
let atlas = bitmap(columns*256,rows*256) { for (index,frame) in frames.enumerated() {
    frame.draw(in:NSRect(x:index%columns*256,y:(rows-1-index/columns)*256,width:256,height:256))
} }
try atlas.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent("chiikawa-\(name)-motion-v30.png"))
let json:[String:Any] = ["source_size":[source.width,source.height],"source_row_edges":rowEdges,"source_column_edges":columnEdges,
    "frame_count":count,"runtime_columns":columns,"runtime_rows":rows,"cell":256,"baseline":26,"head_width":headWidth,"anchor_x":anchor,"frames":report]
try JSONSerialization.data(withJSONObject:json,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("registration.json"))
print("Registered \(count) \(name) frames; native alpha preserved.")
