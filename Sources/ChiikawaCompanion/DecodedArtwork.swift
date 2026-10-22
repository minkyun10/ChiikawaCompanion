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
