import AppKit
final class ProbePanel: NSPanel { override var canBecomeKey: Bool { false }; override var canBecomeMain: Bool { false } }
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.finishLaunching()
let screen = NSScreen.main!.visibleFrame
let point = NSPoint(x: screen.midX, y: screen.midY)
let body = NSPanel(contentRect: NSRect(x: point.x-66,y: point.y-75,width:132,height:150),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
body.level = .floating; body.hidesOnDeactivate=false
body.isOpaque=false;body.backgroundColor = .clear
body.collectionBehavior = [.canJoinAllSpaces,.stationary]
body.orderFrontRegardless();body.displayIfNeeded()
func probe(_ name:String) {
 let hit=NSWindow.windowNumber(at:point,belowWindowWithWindowNumber:0)
 let order=NSWindow.windowNumbers(options:.allApplications)!.map(\.intValue)
 print(name,"body",body.windowNumber,"visible",body.isVisible,"bodyIndex",order.firstIndex(of:body.windowNumber) as Any,"hit",hit,"hitIndex",order.firstIndex(of:hit) as Any)
}
probe("empty immediate")
RunLoop.current.run(until:Date().addingTimeInterval(0.05));probe("empty after loop")
body.ignoresMouseEvents=false;probe("interactive empty")
body.backgroundColor = .white;body.isOpaque=true;body.display();probe("opaque immediate")
let cover=ProbePanel(contentRect:NSRect(x:point.x-12,y:point.y-12,width:24,height:24),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
cover.hidesOnDeactivate=false;cover.backgroundColor = .white;cover.isOpaque=true
cover.contentView = NSView(frame:NSRect(origin:.zero,size:cover.frame.size))
cover.contentView!.wantsLayer=true;cover.contentView!.layer!.backgroundColor=NSColor.white.cgColor
cover.level=NSWindow.Level(rawValue:NSWindow.Level.floating.rawValue+1);cover.orderFrontRegardless();cover.display()
probe("cover immediate")
RunLoop.current.run(until:Date().addingTimeInterval(0.05));probe("cover after loop")
print("cover",cover.windowNumber,cover.frame,cover.isVisible,cover.ignoresMouseEvents)

let initialHit = NSWindow.windowNumber(at:point,belowWindowWithWindowNumber:0)
let all=CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as! [[String:Any]]
for entry in all {
 let id=entry[kCGWindowNumber as String] as? Int ?? -1
 let pid=entry[kCGWindowOwnerPID as String] as? Int ?? -1
 if pid==ProcessInfo.processInfo.processIdentifier || id==initialHit {
  print("CG",id,"own",pid==ProcessInfo.processInfo.processIdentifier,"level",entry[kCGWindowLayer as String] as Any,"bounds",entry[kCGWindowBounds as String] as Any)
 }
}
for pt in [point,NSPoint(x:point.x,y:NSScreen.screens[0].frame.maxY-point.y)] {
 print("coordinate",pt,"hit",NSWindow.windowNumber(at:pt,belowWindowWithWindowNumber:0))
}

let activeOrder=NSWindow.windowNumbers(options:.allApplications)!.map(\.intValue)
var target=NSWindow.windowNumber(at:point,belowWindowWithWindowNumber:0)
for _ in 0..<8 {
 print("descending target",target,"listed",activeOrder.contains(target))
 if let d=all.first(where:{ ($0[kCGWindowNumber as String] as? Int)==target }) { print("target metadata",d[kCGWindowLayer as String] as Any,d[kCGWindowAlpha as String] as Any,d[kCGWindowBounds as String] as Any) }
 if target==0 || activeOrder.contains(target) { break }
 target=NSWindow.windowNumber(at:point,belowWindowWithWindowNumber:target)
}
cover.orderOut(nil);body.orderOut(nil)
