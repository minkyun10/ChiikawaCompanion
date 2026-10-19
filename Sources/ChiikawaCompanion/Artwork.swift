import AppKit

/// Hachiware uses the approved reference-based sprite art; other characters retain vector drafts.
enum FriendArtwork {
    static let ink = NSColor(hex: 0x554944)
    static let paper = NSColor(hex: 0xFFFDF7)

    static func draw(_ friend: Friend, in rect: NSRect, time: Double = 0,
                     happy: Bool = false, walking: Bool = false, looking: CGFloat = 0,
                     facing: CGFloat = 1, walkPhase: Double? = nil, pose: HachiwarePose = .front,
                     action: HachiwareAction? = nil, equipped: CompanionItem? = nil, actionTime: Double? = nil) {
        if friend == .hachiware {
            if let action, HachiwareActions.shared.draw(action, in: rect, time: actionTime ?? time) {
                if let equipped, !action.isDaily && action != equipped.action && action != .pickup {
                    ItemArtwork.drawEquipped(equipped, in: rect, pose: .front, facing: -1, time: time, behind: false)
                }
                return
            }
            let shownPose: HachiwarePose = happy || !walking ? .front : pose
            let phase = walkPhase ?? time / RoamingMotion.previewCycleDuration * 2 * .pi
            let offset = HachiwareSprites.bodyOffset(pose: shownPose, phase: phase) * min(rect.width, rect.height) / 256
            let equipmentRect = rect.offsetBy(dx: 0, dy: offset)
            if let equipped { ItemArtwork.drawEquipped(equipped, in: equipmentRect, pose: shownPose, facing: facing, time: time, behind: true) }
            HachiwareSprites.shared.draw(in: rect, time: time, happy: happy, walking: walking,
                                         facing: facing, walkPhase: walkPhase, pose: pose)
            if let equipped { ItemArtwork.drawEquipped(equipped, in: equipmentRect, pose: shownPose, facing: facing, time: time, behind: false) }
            return
        }
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        let scale = min(rect.width / 160, rect.height / 180)
        cg.translateBy(x: rect.midX - 80 * scale, y: rect.midY - 90 * scale)
        cg.scaleBy(x: scale, y: scale)
        let gait = walkPhase ?? time * 9
        let stride = walking ? CGFloat(sin(gait)) : 0
        let bounce = happy ? abs(sin(time * 7)) * 5 : walking ? abs(sin(gait)) * 3.8 : sin(time * 2) * 0.9
        ellipse(42, 5, 76, 9, fill: NSColor.black.withAlphaComponent(0.09), stroke: false)
        if facing < 0 { cg.translateBy(x: 160, y: 0); cg.scaleBy(x: -1, y: 1) }
        cg.translateBy(x: 0, y: bounce)
        if walking {
            cg.translateBy(x: 80, y: 25)
            cg.rotate(by: stride * 0.035)
            cg.translateBy(x: -80, y: -25)
        }
        let cream = friend == .usagi ? NSColor(hex: 0xFFF0C4) : paper

        if friend == .hachiware {
            let tail = NSBezierPath()
            tail.move(to: NSPoint(x: 57, y: 38))
            tail.curve(to: NSPoint(x: 28, y: 45 + stride * 3),
                       controlPoint1: NSPoint(x: 30, y: 13), controlPoint2: NSPoint(x: 15, y: 27))
            tail.lineCapStyle = .round
            tail.lineWidth = 11; ink.setStroke(); tail.stroke()
            tail.lineWidth = 6.5; friend.color.setStroke(); tail.stroke()
        }

        if friend == .momonga {
            ellipse(104, 21, 39, 42, fill: NSColor(hex: 0xB1BED5))
            ellipse(109, 23, 25, 26, fill: paper, stroke: false)
        }
        ellipse(56 + stride * 6, 12 + max(0, stride) * 5, 20, 13, fill: cream)
        ellipse(85 - stride * 6, 12 + max(0, -stride) * 5, 20, 13, fill: cream)
        ellipse(49, 20, 63, 57, fill: cream)
        let armLift: CGFloat = happy ? 14 + CGFloat(sin(time * 9)) * 4 : 0
        ellipse(36, 40 + armLift + stride * 7, 19, 26, fill: cream)
        ellipse(106, 40 + armLift - stride * 7, 19, 26, fill: cream)
        if walking { cg.translateBy(x: 4, y: 0) }

        switch friend {
        case .usagi:
            capsule(48, 115, 23, 61, fill: cream, radius: 12)
            capsule(89, 115, 23, 61, fill: cream, radius: 12)
            capsule(55, 135, 9, 32, fill: NSColor(hex: 0xF2CFB4), radius: 5, stroke: false)
            capsule(96, 135, 9, 32, fill: NSColor(hex: 0xF2CFB4), radius: 5, stroke: false)
        case .hachiware:
            triangle([NSPoint(x: 29, y: 113), NSPoint(x: 37, y: 151), NSPoint(x: 66, y: 127)], fill: friend.color)
            triangle([NSPoint(x: 94, y: 127), NSPoint(x: 123, y: 151), NSPoint(x: 132, y: 111)], fill: friend.color)
        case .momonga:
            ellipse(23, 113, 35, 37, fill: friend.color)
            ellipse(103, 113, 35, 37, fill: friend.color)
            ellipse(32, 121, 17, 21, fill: NSColor(hex: 0xEDD6DC), stroke: false)
            ellipse(112, 121, 17, 21, fill: NSColor(hex: 0xEDD6DC), stroke: false)
        default:
            let ear = friend == .kurimanju ? NSColor(hex: 0xA68465) : cream
            ellipse(37, 121, 25, 27, fill: ear)
            ellipse(98, 121, 25, 27, fill: ear)
            if friend == .chiikawa {
                ellipse(44, 128, 10, 13, fill: NSColor(hex: 0xF6D6D9), stroke: false)
                ellipse(106, 128, 10, 13, fill: NSColor(hex: 0xF6D6D9), stroke: false)
            }
        }

        ellipse(26, 55, 108, 87, fill: cream)
        if friend == .hachiware {
            let cap = NSBezierPath()
            cap.move(to: NSPoint(x: 27, y: 100))
            cap.curve(to: NSPoint(x: 80, y: 140), controlPoint1: NSPoint(x: 27, y: 130), controlPoint2: NSPoint(x: 56, y: 145))
            cap.curve(to: NSPoint(x: 133, y: 100), controlPoint1: NSPoint(x: 109, y: 145), controlPoint2: NSPoint(x: 133, y: 128))
            cap.curve(to: NSPoint(x: 80, y: 131), controlPoint1: NSPoint(x: 112, y: 103), controlPoint2: NSPoint(x: 91, y: 115))
            cap.curve(to: NSPoint(x: 27, y: 100), controlPoint1: NSPoint(x: 66, y: 113), controlPoint2: NSPoint(x: 50, y: 104))
            cap.close(); friend.color.setFill(); cap.fill()
        }
        if friend == .kurimanju {
            let cap = NSBezierPath()
            cap.move(to: NSPoint(x: 27, y: 108))
            cap.curve(to: NSPoint(x: 133, y: 108), controlPoint1: NSPoint(x: 36, y: 155), controlPoint2: NSPoint(x: 123, y: 155))
            cap.curve(to: NSPoint(x: 27, y: 108), controlPoint1: NSPoint(x: 106, y: 116), controlPoint2: NSPoint(x: 53, y: 116))
            cap.close(); NSColor(hex: 0x9D795B).setFill(); cap.fill()
        }
        if friend == .momonga {
            let cap = NSBezierPath()
            cap.move(to: NSPoint(x: 29, y: 111))
            cap.curve(to: NSPoint(x: 131, y: 111), controlPoint1: NSPoint(x: 39, y: 151), controlPoint2: NSPoint(x: 121, y: 151))
            cap.curve(to: NSPoint(x: 80, y: 129), controlPoint1: NSPoint(x: 108, y: 111), controlPoint2: NSPoint(x: 90, y: 119))
            cap.curve(to: NSPoint(x: 29, y: 111), controlPoint1: NSPoint(x: 66, y: 115), controlPoint2: NSPoint(x: 49, y: 111))
            cap.close(); friend.color.setFill(); cap.fill()
        }
        // Re-outline the face after the colour patches.
        let outline = NSBezierPath(ovalIn: NSRect(x: 26, y: 55, width: 108, height: 87))
        outline.lineWidth = 2.6; outline.lineJoinStyle = .round; ink.setStroke(); outline.stroke()
        ellipse(37, 77, 21, 11, fill: NSColor(hex: 0xF3BBC2, alpha: 0.8), stroke: false)
        ellipse(102, 77, 21, 11, fill: NSColor(hex: 0xF3BBC2, alpha: 0.8), stroke: false)
        let blink = !happy && time.truncatingRemainder(dividingBy: 5.7) > 5.5
        let eyeY: CGFloat = friend == .kurimanju ? 97 : 99
        if happy || blink {
            arcSmile(56, eyeY, radius: 6, upward: happy)
            arcSmile(99, eyeY, radius: 6, upward: happy)
        } else if friend == .momonga {
            ellipse(51 + looking * 1.5, 88, 15, 21, fill: ink, stroke: false)
            ellipse(94 + looking * 1.5, 88, 15, 21, fill: ink, stroke: false)
            ellipse(55, 100, 5, 6, fill: .white, stroke: false)
            ellipse(98, 100, 5, 6, fill: .white, stroke: false)
        } else {
            let eyeLook = walking ? CGFloat(2) : looking * facing * 2
            ellipse(54 + eyeLook, eyeY - 6, 7, 10, fill: ink, stroke: false)
            ellipse(98 + eyeLook, eyeY - 6, 7, 10, fill: ink, stroke: false)
        }
        if friend == .usagi || happy {
            ellipse(73, 75, 14, 16, fill: NSColor(hex: 0xCA7F7B))
            ellipse(76, 76, 8, 5, fill: NSColor(hex: 0xF4B6B4), stroke: false)
        } else {
            stroke([NSPoint(x: 71, y: 85), NSPoint(x: 76, y: 81), NSPoint(x: 80, y: 85), NSPoint(x: 85, y: 81), NSPoint(x: 90, y: 85)], width: 2)
        }
        if friend == .hachiware {
            stroke([NSPoint(x: 33, y: 94), NSPoint(x: 42, y: 92)], width: 1.8)
            stroke([NSPoint(x: 118, y: 92), NSPoint(x: 127, y: 94)], width: 1.8)
        }
        if friend == .kurimanju {
            ellipse(72, 90, 16, 9, fill: NSColor(hex: 0xA98065), stroke: false)
            stroke([NSPoint(x: 68, y: 80), NSPoint(x: 70, y: 76)], width: 1.5)
            stroke([NSPoint(x: 90, y: 80), NSPoint(x: 88, y: 76)], width: 1.5)
        }
        if happy {
            spark(15, 130, size: 7)
            spark(144, 113, size: 5)
        }
        cg.restoreGState()
    }

    static func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                        fill: NSColor, stroke: Bool = true) {
        let p = NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h))
        fill.setFill(); p.fill()
        if stroke { p.lineWidth = 2.6; ink.setStroke(); p.stroke() }
    }
    static func capsule(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                        fill: NSColor, radius: CGFloat, stroke: Bool = true) {
        let p = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: radius, yRadius: radius)
        fill.setFill(); p.fill()
        if stroke { p.lineWidth = 2.6; ink.setStroke(); p.stroke() }
    }
    static func triangle(_ points: [NSPoint], fill: NSColor) {
        let p = NSBezierPath(); p.move(to: points[0]); points.dropFirst().forEach { p.line(to: $0) }; p.close()
        fill.setFill(); p.fill(); p.lineWidth = 2.6; p.lineJoinStyle = .round; ink.setStroke(); p.stroke()
    }
    static func stroke(_ points: [NSPoint], width: CGFloat) {
        let p = NSBezierPath(); p.move(to: points[0]); points.dropFirst().forEach { p.line(to: $0) }
        p.lineWidth = width; p.lineCapStyle = .round; p.lineJoinStyle = .round; ink.setStroke(); p.stroke()
    }
    static func arcSmile(_ x: CGFloat, _ y: CGFloat, radius: CGFloat, upward: Bool) {
        let p = NSBezierPath(); p.move(to: NSPoint(x: x - radius, y: y - 1))
        p.curve(to: NSPoint(x: x + radius, y: y - 1),
                controlPoint1: NSPoint(x: x - 2, y: y + (upward ? 8 : 0)),
                controlPoint2: NSPoint(x: x + 2, y: y + (upward ? 8 : 0)))
        p.lineWidth = 2.5; p.lineCapStyle = .round; ink.setStroke(); p.stroke()
    }
    static func spark(_ x: CGFloat, _ y: CGFloat, size: CGFloat) {
        let p = NSBezierPath(); p.move(to: NSPoint(x: x, y: y + size)); p.line(to: NSPoint(x: x + 2, y: y + 2))
        p.line(to: NSPoint(x: x + size, y: y)); p.line(to: NSPoint(x: x + 2, y: y - 2))
        p.line(to: NSPoint(x: x, y: y - size)); p.line(to: NSPoint(x: x - 2, y: y - 2))
        p.line(to: NSPoint(x: x - size, y: y)); p.line(to: NSPoint(x: x - 2, y: y + 2)); p.close()
        NSColor(hex: 0xE4B85D).setFill(); p.fill()
    }
}

final class PortraitView: NSView {
    var friend: Friend = .chiikawa
    override func draw(_ dirtyRect: NSRect) {
        FriendArtwork.draw(friend, in: bounds.insetBy(dx: 4, dy: 2), time: 1)
    }
}
