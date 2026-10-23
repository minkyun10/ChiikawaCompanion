import AppKit

/// Only registered facial regions change; the T-pose identity, headband, scar,
/// mane, cheeks and outer silhouette remain the same raster in every reaction.
final class NewFriendFace {
    let source: NSBitmapImageRep
    let areas: [NSRect]
    let patches: [NSImage]
    let friend: Friend
    let ink = NSColor(hex: 0x51342B)

    init?(friend: Friend, body: NSImage) {
        guard friend.usesNewFriendRig, let data = body.tiffRepresentation,
              let source = NSBitmapImageRep(data: data) else { return nil }
        self.friend = friend; self.source = source
        switch friend {
        case .rakko:
            areas = [NSRect(x: 155,y: 180,width: 54,height: 43),
                     NSRect(x: 98,y: 147,width: 54,height: 37), NSRect(x: 209,y: 147,width: 54,height: 37)]
        case .shisa:
            areas = [NSRect(x: 173,y: 145,width: 48,height: 63),
                     NSRect(x: 132,y: 111,width: 36,height: 38), NSRect(x: 224,y: 111,width: 36,height: 38)]
        default:
            areas = [NSRect(x: 137,y: 201,width: 48,height: 42),
                     NSRect(x: 93,y: 164,width: 40,height: 40), NSRect(x: 188,y: 164,width: 40,height: 40)]
        }
        patches = areas.map { area in
            let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(area.width),pixelsHigh:Int(area.height),
                bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,
                bytesPerRow:Int(area.width)*4,bitsPerPixel:32)!
            for y in 0..<rep.pixelsHigh {
                let left = source.colorAt(x:Int(area.minX)-2,y:Int(area.minY)+y)!
                let right = source.colorAt(x:Int(area.maxX)+2,y:Int(area.minY)+y)!
                for x in 0..<rep.pixelsWide {
                    let t = CGFloat(x)/CGFloat(rep.pixelsWide-1)
                    rep.setColor(NSColor(deviceRed:left.redComponent*(1-t)+right.redComponent*t,
                        green:left.greenComponent*(1-t)+right.greenComponent*t,
                        blue:left.blueComponent*(1-t)+right.blueComponent*t,alpha:1),atX:x,y:y)
                }
            }
            let image = NSImage(size:area.size); image.addRepresentation(rep); return image
        }
    }
    func destination(_ area: NSRect, in body: NSRect) -> NSRect {
        NSRect(x:body.minX+area.minX/CGFloat(source.pixelsWide)*body.width,
               y:body.maxY-area.maxY/CGFloat(source.pixelsHigh)*body.height,
               width:area.width/CGFloat(source.pixelsWide)*body.width,
               height:area.height/CGFloat(source.pixelsHigh)*body.height)
    }
    func draw(_ action: RosterAction, phase: Double, in body: NSRect) {
        if friend == .rakko && action == .attack {
            // A focused, level gaze suits Rakko. Keep the small closed mouth,
            // star scar, cheeks and cape exactly as in the approved body.
            for index in 1...2 {
                let rect = destination(areas[index],in:body)
                patches[index].draw(in:rect)
                let eye = NSBezierPath(ovalIn:NSRect(x:rect.minX+3,y:rect.midY-5,width:rect.width-6,height:9))
                ink.setFill(); eye.fill()
                NSColor(hex:0xFFFBEB).setFill()
                NSBezierPath(ovalIn:NSRect(x:rect.midX-3,y:rect.midY,width:7,height:2.7)).fill()
                let brow = NSBezierPath(); brow.move(to:NSPoint(x:rect.minX+3,y:rect.maxY-2+(index == 1 ? 1:0)))
                brow.line(to:NSPoint(x:rect.maxX-3,y:rect.maxY-2+(index == 1 ? 0:1)))
                brow.lineWidth=1.8; brow.lineCapStyle = .round; ink.setStroke(); brow.stroke()
            }
            return
        }
        guard [.laugh,.surprised,.sleep,.wake,.keepsake].contains(action) else { return }
        let blink = action == .sleep || (action == .wake && phase < 0.25)
            || (action == .keepsake && phase > 0.78 && phase < 0.93)
        if blink {
            for index in 1...2 {
                let rect = destination(areas[index],in:body)
                patches[index].draw(in:rect)
                let eye = NSBezierPath(); eye.move(to:NSPoint(x:rect.minX+2,y:rect.midY))
                eye.curve(to:NSPoint(x:rect.maxX-2,y:rect.midY),
                    controlPoint1:NSPoint(x:rect.midX-3,y:rect.midY-3),controlPoint2:NSPoint(x:rect.midX+3,y:rect.midY-3))
                eye.lineWidth=2.1;eye.lineCapStyle = .round;ink.setStroke();eye.stroke()
            }
        }
        // Reading preserves Kani's gentle original mouth; Shisa already smiles.
        if action == .keepsake && friend != .rakko { return }
        let rect = destination(areas[0],in:body)
        patches[0].draw(in:rect)
        let center = NSPoint(x:rect.midX,y:rect.midY)
        let mouth = NSBezierPath()
        ink.setStroke(); ink.setFill()
        if action == .sleep || (action == .keepsake && phase > 0.48) {
            mouth.move(to:NSPoint(x:center.x-4,y:center.y+1))
            mouth.curve(to:NSPoint(x:center.x+4,y:center.y+1),controlPoint1:NSPoint(x:center.x-2,y:center.y-3),controlPoint2:NSPoint(x:center.x+2,y:center.y-3))
            mouth.lineWidth=2;mouth.lineCapStyle = .round;mouth.stroke()
        } else if action == .surprised {
            NSBezierPath(ovalIn:NSRect(x:center.x-3,y:center.y-4,width:6,height:8)).fill()
        } else {
            let open = NSBezierPath(roundedRect:NSRect(x:center.x-5,y:center.y-7,width:10,height:13),xRadius:5,yRadius:5)
            open.fill();NSColor(hex:0xEBA0AC).setFill()
            NSBezierPath(ovalIn:NSRect(x:center.x-3,y:center.y-5,width:6,height:4)).fill()
            // Retain the original nose and omega-shaped upper lip.
            let area=areas[0], strip=NSRect(x:area.minX,y:area.minY,width:area.width,height:friend == .shisa ? 23:24)
            let original=NSImage(cgImage:source.cgImage!,size:NSSize(width:source.pixelsWide,height:source.pixelsHigh))
            original.draw(in:destination(strip,in:body),from:NSRect(x:strip.minX,y:CGFloat(source.pixelsHigh)-strip.maxY,width:strip.width,height:strip.height),operation:.sourceOver,fraction:1)
        }
    }
}
