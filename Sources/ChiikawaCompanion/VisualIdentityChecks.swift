import AppKit

extension SelfTest {
    /// TIFF containers may encode different hidden RGB/metadata after a provider
    /// change. Compare the actual composited pixels at 1x and Retina scale.
    static func visiblePixels(_ image:NSImage,edge:Int)->Data {
        let bitmap=RosterNativeRig.bitmap(NSSize(width:edge,height:edge)) {
            image.draw(in:NSRect(x:0,y:0,width:edge,height:edge))
        }
        return Data(bytes:bitmap.bitmapData!,count:bitmap.bytesPerRow*bitmap.pixelsHigh)
    }
}
