import AppKit
import QuartzCore
let app=NSApplication.shared;app.setActivationPolicy(.accessory);app.finishLaunching()
let rect=NSRect(x:700,y:200,width:100,height:100)
let panel=NSPanel(contentRect:rect,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
panel.level = .screenSaver;panel.isFloatingPanel=false;panel.hidesOnDeactivate=false;panel.isOpaque=true;panel.backgroundColor = .white;panel.ignoresMouseEvents=false;panel.isReleasedWhenClosed=false
panel.contentView=NSView(frame:NSRect(origin:.zero,size:rect.size));panel.contentView!.wantsLayer=true;panel.contentView!.layer!.backgroundColor=NSColor.white.cgColor
panel.orderFrontRegardless();panel.display();app.updateWindows();CATransaction.flush();RunLoop.main.run(until:Date().addingTimeInterval(2))
print("panel",panel.windowNumber,panel.frame,panel.ignoresMouseEvents,panel.isOnActiveSpace)
for point in [NSPoint(x:750,y:250),NSPoint(x:750,y:650)] { print("hit",point,NSWindow.windowNumber(at:point,belowWindowWithWindowNumber:0)) }
for w in CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as! [[String:Any]] { if (w[kCGWindowOwnerPID as String] as? Int ?? -1) == Int(ProcessInfo.processInfo.processIdentifier) {print(w)} }
panel.close()
