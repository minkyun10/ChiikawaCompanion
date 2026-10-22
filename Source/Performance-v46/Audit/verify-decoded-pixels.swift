import AppKit

extension NSBitmapImageRep {
    /// Cropping a PNG-backed CGImage retains its lazy PNG provider. With many
    /// characters ImageIO repeatedly inflates the entire sheet during display.
    /// Own the exact source raster once, preserving its palette/profile/alpha.
    var decodedArtwork: CGImage? {
        guard let source=cgImage,let pixels=source.dataProvider?.data,
              CFDataGetLength(pixels)>=source.bytesPerRow*source.height,
              let space=source.colorSpace,let provider=CGDataProvider(data:pixels) else {return nil}
        return CGImage(width:source.width,height:source.height,
            bitsPerComponent:source.bitsPerComponent,bitsPerPixel:source.bitsPerPixel,
            bytesPerRow:source.bytesPerRow,space:space,bitmapInfo:source.bitmapInfo,
            provider:provider,decode:source.decode,shouldInterpolate:source.shouldInterpolate,
            intent:source.renderingIntent)
    }
}

import CryptoKit
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let assets=root.appendingPathComponent("Sources/ChiikawaCompanion/Resources")
let atlases=root.appendingPathComponent("build/roster")
var records:[[String:Any]]=[]
let urls=try FileManager.default.contentsOfDirectory(at:assets,includingPropertiesForKeys:nil).filter{$0.pathExtension=="png"}
    + ["usagi","kurimanju","momonga","rakko","shisa","kani"].flatMap{ friend in
        (try? FileManager.default.contentsOfDirectory(at:atlases.appendingPathComponent(friend),includingPropertiesForKeys:nil))?.filter{$0.lastPathComponent.hasSuffix("-24.png") || $0.lastPathComponent.hasSuffix("-12.png")} ?? []
    }
for url in urls {
    autoreleasepool {
        let bitmap=NSBitmapImageRep(data:try! Data(contentsOf:url))!
        let source=bitmap.cgImage!,decoded=bitmap.decodedArtwork!
        let original=source.dataProvider!.data! as Data,reused=decoded.dataProvider!.data! as Data
        precondition(original==reused,url.lastPathComponent)
        precondition(source.bitsPerPixel==decoded.bitsPerPixel && source.bitmapInfo==decoded.bitmapInfo)
        records.append(["file":url.path.replacingOccurrences(of:root.path+"/",with:""),"samePixels":true,"bytes":original.count,"sha256":SHA256.hash(data:original).map{String(format:"%02x",$0)}.joined()])
    }
}
try JSONSerialization.data(withJSONObject:records,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("Source/Performance-v46/Audit/decoded-pixel-identity.json"))
print("Exact decoded pixel identity:",records.count,"assets/atlases")
