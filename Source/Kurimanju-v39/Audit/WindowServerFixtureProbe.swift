import AppKit
import QuartzCore
final class FP:NSPanel {override var canBecomeKey:Bool {false};override var canBecomeMain:Bool {false}}
let app=NSApplication.shared;app.setActivationPolicy(.accessory);app.finishLaunching()
let pointer=NSPoint(x:720,y:474)
let actor=FP(contentRect:NSRect(x:654,y:399,width:132,height:150),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
actor.isOpaque=false;actor.backgroundColor = .clear;actor.isFloatingPanel=false;actor.level = .floating;actor.collectionBehavior=[.canJoinAllSpaces,.stationary,.ignoresCycle,.fullScreenNone,.fullScreenDisallowsTiling];actor.hidesOnDeactivate=false;actor.isReleasedWhenClosed=false;actor.ignoresMouseEvents=false;actor.orderFrontRegardless()
let cover=FP(contentRect:NSRect(x:708,y:462,width:24,height:24),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
cover.isFloatingPanel=false;cover.level=NSWindow.Level(rawValue:NSWindow.Level.floating.rawValue+1);cover.isReleasedWhenClosed=false;cover.hidesOnDeactivate=false;cover.collectionBehavior=actor.collectionBehavior;cover.isOpaque=true;cover.backgroundColor = .white;cover.ignoresMouseEvents=false
cover.contentView=NSView(frame:NSRect(origin:.zero,size:cover.frame.size));cover.contentView!.wantsLayer=true;cover.contentView!.layer!.backgroundColor=NSColor.white.cgColor
cover.orderFrontRegardless();cover.display();app.updateWindows();CATransaction.flush();RunLoop.main.run(until:Date().addingTimeInterval(1))
print("order has cover",NSWindow.windowNumbers(options:.allApplications)!.map(\.intValue).contains(cover.windowNumber));print("cover",cover.windowNumber,cover.level,cover.ignoresMouseEvents,cover.isOnActiveSpace,"hit",NSWindow.windowNumber(at:pointer,belowWindowWithWindowNumber:0))
for w in CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as! [[String:Any]] {if (w[kCGWindowOwnerPID as String] as? Int ?? -1)==Int(ProcessInfo.processInfo.processIdentifier){print(w)}}
cover.close();actor.close()
