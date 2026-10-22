import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    var desktop: DesktopController!
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        desktop = DesktopController(state: state)
        state.onReset = { [weak self] in self?.resetPositions() }
        setupMenu()
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(item("친구 설정…", action: #selector(showSettings), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(item("종료", action: #selector(quit), key: "q"))
        appItem.submenu = appMenu; mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
        showSettings()
    }

    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "치이카와 데스크톱")
            button.toolTip = "치이카와 데스크톱"
        }
        let menu = NSMenu()
        let title = NSMenuItem(title: "치이카와 데스크톱", action: nil, keyEquivalent: "")
        title.isEnabled = false; menu.addItem(title)
        menu.addItem(item("친구 설정…", action: #selector(showSettings), key: ","))
        menu.addItem(item("모두 부르기", action: #selector(resetPositions)))
        for friend in Friend.developmentRoster {
            let entry = item("\(friend.name) 부르기", action: #selector(callFriend(_:)))
            entry.representedObject = friend.rawValue; menu.addItem(entry)
        }
        menu.addItem(item("모든 친구 표시 / 숨기기", action: #selector(toggleFriends)))
        menu.addItem(item("걷기 켜기 / 끄기", action: #selector(toggleRoaming)))
        let daily = NSMenuItem(title: "하치와레의 하루", action: nil, keyEquivalent: "")
        let dailyMenu = NSMenu()
        for action in HachiwareAction.daily {
            let entry = item(action.title, action: #selector(playDailyAction(_:)))
            entry.tag = action.rawValue; dailyMenu.addItem(entry)
        }
        dailyMenu.addItem(.separator())
        dailyMenu.addItem(item("동작 멈추기", action: #selector(stopDailyAction)))
        daily.submenu = dailyMenu; menu.addItem(daily)
        let chiiDay = NSMenuItem(title: "치이카와의 하루",action: nil,keyEquivalent: "")
        let chiiMenu = NSMenu()
        for action in ChiikawaLifeAction.allCases {
            let entry = item(action.title,action: #selector(playChiikawaLife(_:)))
            entry.representedObject = action.rawValue; chiiMenu.addItem(entry)
        }
        chiiMenu.addItem(item("집에 가서 자기",action: #selector(chiikawaGoHome)))
        chiiMenu.addItem(item("깨우기",action: #selector(chiikawaWake)))
        chiiMenu.addItem(item("목소리 들어보기",action: #selector(chiikawaVoicePreview)))
        chiiMenu.addItem(item("동작 멈추기",action: #selector(stopChiikawaLife)))
        chiiDay.submenu = chiiMenu; menu.addItem(chiiDay)
        for friend in Friend.developmentRoster where friend.isExpansion {
            let entry = NSMenuItem(title: "\(friend.name)의 하루", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            var commands = RosterAction.selectable.map { ($0 == .keepsake ? friend.keepsakeActionTitle : $0.title, "action:" + $0.rawValue) }
                + [("집에 가서 자기", "home"), ("깨우기", "wake"), ("동작 멈추기", "stop")]
            if !RosterRecordingCatalog.catalog(for: friend).clips.isEmpty {
                commands += [("목소리 들어보기", "voice"), ("소리 멈추기", "mute")]
            }
            for (title, command) in commands {
                let button = item(title, action: #selector(rosterCommand(_:)))
                button.representedObject = [friend.rawValue, command]; sub.addItem(button)
            }
            entry.submenu = sub; menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(item("종료", action: #selector(quit), key: "q"))
        statusItem.menu = menu
    }
    func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: key)
        result.target = self; return result
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingView(rootView: SettingsView(state: state))
            let size = host.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                                  styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "치이카와 데스크톱 · 친구 설정"
            window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(hex: 0xF7F4EB)
            window.isReleasedWhenClosed = false
            window.contentView = host; window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func callFriend(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let friend = Friend(rawValue: value) else { return }
        desktop.callFriend(friend)
    }
    @objc func resetPositions() { Friend.developmentRoster.forEach { desktop.callFriend($0) } }
    @objc func toggleFriends() { state.showFriends.toggle() }
    @objc func toggleRoaming() { state.roaming.toggle() }
    @objc func playDailyAction(_ sender: NSMenuItem) {
        guard let action = HachiwareAction(rawValue: sender.tag), action.isDaily else { return }
        desktop.playDailyAction(action)
    }
    @objc func stopDailyAction() { desktop.stopDailyAction() }
    @objc func playChiikawaLife(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = ChiikawaLifeAction(rawValue: raw) else { return }
        if action == .study { desktop.seekChiikawaStudy() } else if action == .eat { desktop.seekChiikawaFood() } else { desktop.playChiikawaLife(action) }
    }
    @objc func chiikawaGoHome() { desktop.goChiikawaHome() }
    @objc func chiikawaWake() { desktop.wakeChiikawa(animated: true) }
    @objc func chiikawaVoicePreview() { desktop.sayChiikawa(preview: true) }
    @objc func stopChiikawaLife() { desktop.stopChiikawaLife() }
    @objc func rosterCommand(_ sender: NSMenuItem) {
        guard let parts = sender.representedObject as? [String], parts.count == 2, let friend = Friend(rawValue: parts[0]) else { return }
        let value = parts[1]
        let command: RosterCommand
        if value.hasPrefix("action:"), let action = RosterAction(rawValue: String(value.dropFirst(7))) { command = .action(action) }
        else { switch value { case "home": command = .home; case "wake": command = .wake; case "voice": command = .voicePreview
            case "mute": command = .stopVoice; default: command = .stopAction } }
        state.onRosterCommand?(friend, command)
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { desktop?.stopCharacterVoice(); desktop?.stopChiikawaVoice(); desktop?.expansions.values.forEach { $0.voice.stop() } }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let args = CommandLine.arguments
if args.contains("--self-test-roster") {
    var count=0
    SelfTest.runRosterChecks { passed, label in
        guard passed else { fputs("FAIL: \(label)\n",stderr);exit(1) }
        count += 1;print("PASS: \(label)")
    }
    print("\(count) roster checks passed.")
} else if args.contains("--self-test") {
    SelfTest.run()
} else if let index = args.firstIndex(of: "--render-roster"), index + 1 < args.count {
    SelfTest.renderRoster(to: args[index + 1])
} else if let index = args.firstIndex(of: "--render-artwork"), index + 1 < args.count {
    SelfTest.renderArtwork(to: args[index + 1])
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
