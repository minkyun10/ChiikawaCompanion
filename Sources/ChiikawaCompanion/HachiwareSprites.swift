import AppKit

enum HachiwarePose: Int, CaseIterable {
    case front, side, back, greeting, frontDiagonal, backDiagonal

    var frameCount: Int { self == .greeting ? 6 : self == .side ? 24 : 12 }
    var canMirror: Bool { self == .side || self == .frontDiagonal || self == .backDiagonal }

    static func forVelocity(_ velocity: CGVector) -> HachiwarePose {
        let x = abs(velocity.dx), y = abs(velocity.dy)
        guard hypot(x, y) > 0.5 else { return .front }
        let boundary: CGFloat = 1 + sqrt(2)
        if y > x * boundary { return velocity.dy > 0 ? .back : .front }
        if x > y * boundary { return .side }
        return velocity.dy > 0 ? .backDiagonal : .frontDiagonal
    }
}

/// Cache registered artwork once. The live loop only selects and draws frames.
final class HachiwareSprites {
    static let shared = HachiwareSprites()
    static let columns = 6
    static let assetNames = ["hachiware-sprites-v1", "hachiware-cardinal-walk-approved-v5",
                             "hachiware-diagonal-matched-walk-v5", "hachiware-diagonal-walk-12-v2",
                             "hachiware-side-walk-24-v9"]
    private(set) var frames = [[NSImage]](repeating: [], count: HachiwarePose.allCases.count)
    private(set) var alphaBounds = [[NSRect]](repeating: [], count: HachiwarePose.allCases.count)
    private(set) var sourceSizes: [String: NSSize] = [:]
    var isReady: Bool { HachiwarePose.allCases.allSatisfy { frames[$0.rawValue].count == $0.frameCount } }

    static func assetURL(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Resources")
    }

    private init() {
        // Cuts lie inside actual transparent gutters, which vary in generated atlases.
        loadAtlas(named: Self.assetNames[0], size: NSSize(width: 1536, height: 1024),
                  edges: [0, 266, 506, 745, 1024], groups: [(.greeting, [3])])
        loadAtlas(named: Self.assetNames[1], size: NSSize(width: 1254, height: 1254),
                  edges: [0, 223, 422, 622, 821, 1020, 1254],
                  groups: [(.front, [0, 1]), (.back, [4, 5])])
        // These approved frames already share one fixed body registration. Loading them
        // directly preserves the reviewed foot dimensions and avoids per-frame rescaling.
        loadRegisteredAtlas(named: Self.assetNames[2], poses: [.frontDiagonal])
        // The user explicitly chose to retain the existing upward diagonal animation.
        loadAtlas(named: Self.assetNames[3], size: NSSize(width: 1536, height: 1024),
                  edges: [0, 274, 522, 764, 1024], groups: [(.backDiagonal, [0, 1])])
        // Reviewed 24-frame side cycle: keep its original body bob, foot size and
        // chronological order. Per-frame head registration would erase the down/up poses.
        loadRegisteredAtlas(named: Self.assetNames[4], poses: [.side], columns: 6)
    }

    private func loadRegisteredAtlas(named name: String, poses: [HachiwarePose], columns: Int = 12) {
        guard let first = poses.first, first.frameCount % columns == 0,
              poses.allSatisfy({ $0.frameCount == first.frameCount }) else { return }
        let rowsPerPose = first.frameCount / columns
        guard let url = Self.assetURL(named: name), let data = try? Data(contentsOf: url),
              let bitmap = NSBitmapImageRep(data: data), let atlas = bitmap.cgImage,
              atlas.width == columns * 256, atlas.height == poses.count * rowsPerPose * 256 else { return }
        sourceSizes[name] = NSSize(width: atlas.width, height: atlas.height)
        for (row, pose) in poses.enumerated() {
            var registered: [NSImage] = []
            var bounds: [NSRect] = []
            for index in 0..<pose.frameCount {
                let column = index % columns, sourceRow = row * rowsPerPose + index / columns
                guard let image = atlas.cropping(to: CGRect(x: column * 256, y: sourceRow * 256,
                                                           width: 256, height: 256)) else { return }
                let pixels = NSBitmapImageRep(cgImage: image)
                var left = 256, right = 0, top = 256, bottom = 0
                for y in 0..<256 {
                    for x in 0..<256 where (pixels.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.25 {
                        left = min(left, x); right = max(right, x)
                        top = min(top, y); bottom = max(bottom, y)
                    }
                }
                guard right > left, bottom > top else { return }
                registered.append(NSImage(cgImage: image, size: NSSize(width: 256, height: 256)))
                bounds.append(NSRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1))
            }
            frames[pose.rawValue] = registered
            alphaBounds[pose.rawValue] = bounds
        }
    }

    private struct SourceFrame {
        let image: CGImage
        let cell: NSRect
        let bounds: NSRect
        let headCenter: CGFloat
        let headWidth: CGFloat
    }

    private func loadAtlas(named name: String, size: NSSize, edges: [Int],
                           groups: [(HachiwarePose, [Int])]) {
        guard let url = Self.assetURL(named: name), let data = try? Data(contentsOf: url),
              let bitmap = NSBitmapImageRep(data: data), let atlas = bitmap.cgImage,
              atlas.width == Int(size.width), atlas.height == Int(size.height) else { return }
        sourceSizes[name] = size
        let width = atlas.width, height = atlas.height, cellWidth = width / Self.columns
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let success = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(atlas, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard success else { return }

        for (pose, rows) in groups {
            var sources: [SourceFrame] = []
            for row in rows {
                for column in 0..<Self.columns {
                    let x0 = column * cellWidth, y0 = edges[row], y1 = edges[row + 1]
                    var left = x0 + cellWidth, right = x0, top = y1, bottom = y0
                    for y in y0..<y1 {
                        for x in x0..<(x0 + cellWidth) where rgba[(y * width + x) * 4 + 3] > 64 {
                            left = min(left, x); right = max(right, x)
                            top = min(top, y); bottom = max(bottom, y)
                        }
                    }
                    guard right > left, bottom > top else { return }
                    var headLeft = right, headRight = left
                    let headTop = top + Int(Double(bottom - top) * 0.2)
                    let headBottom = top + Int(Double(bottom - top) * 0.55)
                    for y in headTop...headBottom {
                        for x in left...right where rgba[(y * width + x) * 4 + 3] > 64 {
                            headLeft = min(headLeft, x); headRight = max(headRight, x)
                        }
                    }
                    let cell = NSRect(x: x0, y: y0, width: cellWidth, height: y1 - y0)
                    guard let cropped = atlas.cropping(to: cell) else { return }
                    sources.append(SourceFrame(image: cropped, cell: cell,
                        bounds: NSRect(x: left - x0, y: top - y0, width: right - left + 1, height: bottom - top + 1),
                        headCenter: CGFloat(headLeft + headRight) / 2 - CGFloat(x0),
                        headWidth: CGFloat(headRight - headLeft + 1)))
                }
            }
            guard sources.count == pose.frameCount else { return }
            func median(_ values: [CGFloat]) -> CGFloat { values.sorted()[values.count / 2] }
            let naturalHeight = median(sources.map { $0.bounds.height })
            let headWidth = median(sources.map { $0.headWidth })
            var registered: [NSImage] = []
            for source in sources {
                let canvas = NSSize(width: 256, height: 256)
                let target = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 1024, bitsPerPixel: 32)!
                guard let graphics = NSGraphicsContext(bitmapImageRep: target) else { return }
                // Stabilize crown position and head width; add deliberate bob during playback.
                let scale = 208 / naturalHeight * headWidth / source.headWidth
                let drawRect = NSRect(x: 128 - source.headCenter * scale,
                    y: 236 - (source.cell.height - source.bounds.minY) * scale,
                    width: source.cell.width * scale, height: source.cell.height * scale)
                NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
                graphics.imageInterpolation = .high
                NSImage(cgImage: source.image, size: source.cell.size)
                    .draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
                graphics.flushGraphics(); NSGraphicsContext.restoreGraphicsState()
                guard let image = target.cgImage else { return }
                registered.append(NSImage(cgImage: image, size: canvas))
            }
            frames[pose.rawValue] = registered
            alphaBounds[pose.rawValue] = sources.map(\.bounds)
        }
    }

    static func frameIndex(phase: Double, count: Int = 12) -> Int {
        let index = Int(floor(phase / (2 * .pi) * Double(count)))
        return ((index % count) + count) % count
    }

    /// The side atlas already contains the weight shift. Accessories follow the
    /// selected drawing, including its discrete frame timing, rather than bobbing independently.
    static func bodyOffset(pose: HachiwarePose, phase: Double) -> CGFloat {
        guard pose == .side else { return 0 }
        let frame = frameIndex(phase: phase, count: pose.frameCount)
        return -5.5 * sin(Double(frame) / Double(pose.frameCount) * 4 * .pi)
    }

    func frame(pose: HachiwarePose, index: Int) -> NSImage? {
        guard isReady else { return nil }
        let cycle = frames[pose.rawValue]
        return cycle[((index % cycle.count) + cycle.count) % cycle.count]
    }

    @discardableResult
    func draw(in rect: NSRect, time: Double, happy: Bool, walking: Bool,
              facing: CGFloat, walkPhase: Double?, pose: HachiwarePose) -> Bool {
        let selectedPose: HachiwarePose = happy ? .greeting : walking ? pose : .front
        let phase = walkPhase ?? time / RoamingMotion.previewCycleDuration * 2 * .pi
        let index = happy ? Int(time * 5) % selectedPose.frameCount
            : walking ? Self.frameIndex(phase: phase, count: selectedPose.frameCount) : 0
        guard let image = frame(pose: selectedPose, index: index),
              let context = NSGraphicsContext.current?.cgContext else { return false }
        let length = min(rect.width, rect.height)
        let bob = walking && !happy && selectedPose == .backDiagonal
            ? CGFloat(cos(phase * 2)) * length * 0.004
            : !walking && !happy ? CGFloat(sin(time * 2)) * length * 0.003 : 0
        let destination = NSRect(x: rect.midX - length / 2, y: rect.midY - length / 2 + bob,
                                 width: length, height: length)
        context.saveGState()
        if selectedPose.canMirror && facing > 0 {
            context.translateBy(x: rect.midX * 2, y: 0); context.scaleBy(x: -1, y: 1)
        }
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
        context.restoreGState()
        return true
    }
}
