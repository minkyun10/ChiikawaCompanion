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

let data=try Data(contentsOf:URL(fileURLWithPath:"Sources/ChiikawaCompanion/Resources/chiikawa-down-24.png"))
let bitmap=NSBitmapImageRep(data:data)!
let crop=CGRect(x:0,y:0,width:256,height:256)
let a=NSImage(cgImage:bitmap.cgImage!.cropping(to:crop)!,size:crop.size)
let b=NSImage(cgImage:bitmap.decodedArtwork!.cropping(to:crop)!,size:crop.size)
func pixels(_ image:NSImage,_ edge:Int)->Data {
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:edge,pixelsHigh:edge,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:edge*4,bitsPerPixel:32)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
 let bounds=NSRect(x:0,y:0,width:edge,height:edge)
 NSGraphicsContext.current!.cgContext.clear(bounds);NSGraphicsContext.current!.imageInterpolation = .high
 image.draw(in:bounds);NSGraphicsContext.current!.flushGraphics();NSGraphicsContext.restoreGraphicsState()
 return Data(bytes:rep.bitmapData!,count:rep.bytesPerRow*rep.pixelsHigh)
}
print("TIFF bytes identical:",a.tiffRepresentation==b.tiffRepresentation)
for edge in [256,512] {print("Rendered pixels identical at",edge,":",pixels(a,edge)==pixels(b,edge))}
