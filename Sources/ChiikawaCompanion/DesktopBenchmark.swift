import AppKit
import QuartzCore
import Darwin

/// Real-time AppKit windows and drawing; isolated preferences never change the user's setup.
enum DesktopBenchmark {
    static func run(output: String, seconds: Double, counts:[Int]=[1,2,4,6,8], automaticItems:Bool=false, monster:Bool=false) {
        let app=NSApplication.shared;app.setActivationPolicy(.accessory);app.finishLaunching()
        let suite="DesktopBenchmark-\(UUID().uuidString)", defaults=UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        let state=AppState(defaults:defaults)
        state.automaticRest=false;state.chiikawaAutomaticRest=false
        state.automaticItems=automaticItems;state.chiikawaAutomaticItems=automaticItems
        state.automaticActivities=automaticItems;state.chiikawaAutomaticActivities=automaticItems
        state.characterVoice=false;state.chiikawaVoice=false
        for friend in Friend.expansionOrder {state.updateOptions(friend){$0.automaticItems=automaticItems;$0.automaticRest=false;$0.voice=false}}
        let desktop=DesktopController(state:state,startTimer:false)
        if monster, let actor = desktop.hachiwareActor { for _ in 0..<5 { desktop.handleCharacterClick(actor) } }
        let bounds=NSScreen.main!.visibleFrame
        var results:[[String:Any]]=[]
        func cpu()->Double {
            var usage=rusage();getrusage(RUSAGE_SELF,&usage)
            return Double(usage.ru_utime.tv_sec+usage.ru_stime.tv_sec)+Double(usage.ru_utime.tv_usec+usage.ru_stime.tv_usec)/1_000_000
        }
        func percentile(_ values:[Double],_ fraction:Double)->Double {
            let sorted=values.sorted();return sorted.isEmpty ? 0:sorted[min(sorted.count-1,Int(Double(sorted.count-1)*fraction))]
        }
        for count in counts {
            state.visibleFriends=Set(Friend.developmentRoster.prefix(count))
            state.walkingFriends=state.visibleFriends;state.showFriends=true;state.roaming=true
            for (i,actor) in desktop.actors.enumerated() {
                actor.panel.setFrameOrigin(RoamingMotion.target(in:bounds,size:actor.panel.frame.size,xFraction:i%2 == 0 ? 0.08:0.82,yFraction:0.20+Double(i)*0.055))
                actor.motion.retarget()
                actor.motion.destination=RoamingMotion.target(in:bounds,size:actor.panel.frame.size,xFraction:i%2 == 0 ? 0.92:0.04,yFraction:0.72-Double(i)*0.045)
            }
            var intervals:[Double]=[],costs:[Double]=[],last:Double?
            let start=CACurrentMediaTime(),measure=start+2,end=measure+seconds,cpuStart=cpu()
            let timer=Timer(timeInterval:DesktopActivity.updateInterval,repeats:true) { _ in
                let began=CACurrentMediaTime()
                desktop.tick(pointer:NSPoint(x:-10000,y:-10000),pointerCanReachCharacter:false)
                // Include pending view drawing, not only movement scheduling.
                for window in NSApp.windows where window.isVisible { window.displayIfNeeded() }
                let finished=CACurrentMediaTime()
                if began>=measure {
                    if let last { intervals.append((began-last)*1000) }
                    costs.append((finished-began)*1000)
                }
                last=began
            }
            timer.tolerance=0.002;RunLoop.main.add(timer,forMode:.common)
            while CACurrentMediaTime()<end { RunLoop.main.run(until:Date().addingTimeInterval(0.05)) }
            timer.invalidate()
            let missed=intervals.filter{$0>25}.count
            let record:[String:Any]=["characters":count,"samples":intervals.count,
                "callbackHz":intervals.isEmpty ? 0:1000/(intervals.reduce(0,+)/Double(intervals.count)),
                "intervalP95ms":percentile(intervals,0.95),"intervalP99ms":percentile(intervals,0.99),
                "intervalMaxms":intervals.max() ?? 0,"over25msPercent":Double(missed)*100/Double(max(1,intervals.count)),
                "workP95ms":percentile(costs,0.95),"workMaxms":costs.max() ?? 0,
                "cpuPercentOfOneCore":(cpu()-cpuStart)/(CACurrentMediaTime()-start)*100]
            results.append(record)
            print("Bench \(count): \(record)");fflush(stdout)
        }
        let report:[String:Any]=["date":"2026-10-23","secondsPerCount":seconds,"warmupSeconds":2,
            "hachiwareMonster":monster,
            "screenPoints":[bounds.width,bounds.height],"backingScale":NSScreen.main!.backingScaleFactor,
            "method":"60 Hz main-run-loop callback plus synchronous displayIfNeeded on actual AppKit windows; not compositor-present FPS",
            "scene":automaticItems ? "All eight characters with owned props and autonomous pickup/activities enabled; rest/audio disabled to keep cast visible; pointer away; no settings window" : "All owned ground props enabled; continuously walking; autonomous pickup/rest/activities and audio disabled; pointer away; no settings window",
            "results":results]
        try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:output))
    }
}
