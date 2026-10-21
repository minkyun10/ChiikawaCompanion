import AppKit
import ImageIO
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let source = CGImageSourceCreateWithURL(root.appendingPathComponent("chiikawa-walking-blink-v30.gif") as CFURL,nil)!
let image = CGImageSourceCreateImageAtIndex(source,77,nil)!
try NSBitmapImageRep(cgImage: image).representation(using: .png,properties: [:])!
    .write(to: root.appendingPathComponent("chiikawa-walking-blink-closed-v30.png"))
