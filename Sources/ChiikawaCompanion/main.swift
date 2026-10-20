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
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { desktop?.stopCharacterVoice() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let args = CommandLine.arguments
if args.contains("--self-test") {
    SelfTest.run()
} else if let index = args.firstIndex(of: "--render-artwork"), index + 1 < args.count {
    SelfTest.renderArtwork(to: args[index + 1])
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
