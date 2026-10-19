import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    let monitor = KakaoNotificationMonitor()
    var desktop: DesktopController!
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        desktop = DesktopController(state: state)
        state.onDemo = { [weak self] friend in
            guard let self else { return }
            let sender = self.state.assignments.first(where: { $0.friend == friend })?.sender ?? ""
            self.desktop.notify(friend, sender: sender.isEmpty ? "테스트 친구" : sender,
                                body: "오늘 뭐해? 같이 산책할래?", demo: true)
        }
        state.onReset = { [weak self] in self?.desktop.resetPositions() }
        state.onMonitoringChange = { [weak self] enabled in
            guard let self else { return }
            if enabled { self.monitor.start() }
            else { self.monitor.stop(); self.state.monitoringStatus = "꺼져 있어요" }
        }
        monitor.onStatus = { [weak self] status in
            guard let self, self.state.monitoring else { return }
            self.state.monitoringStatus = status
        }
        monitor.onAccessChange = { [weak self] available in self?.state.accessibilityAvailable = available }
        monitor.onNotification = { [weak self] event in
            guard let self, self.state.monitoring,
                  let friend = SenderMatcher.match(event.sender, in: self.state.activeAssignments) else { return }
            self.state.verifiedSession = true
            let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
            self.state.lastEvent = "\(time) · \(event.sender) → \(friend.name)"
            self.desktop.notify(friend, sender: event.sender, body: event.body)
        }
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
        menu.addItem(item("하치와레 부르기", action: #selector(resetPositions)))
        menu.addItem(item("하치와레 표시 / 숨기기", action: #selector(toggleFriends)))
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
        let demos = NSMenuItem(title: "알림 시연", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (index, friend) in Friend.developmentRoster.enumerated() {
            let entry = item(friend.name, action: #selector(demo(_:))); entry.tag = index
            submenu.addItem(entry)
        }
        demos.submenu = submenu; menu.addItem(demos)
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
    @objc func resetPositions() { desktop.resetPositions() }
    @objc func toggleFriends() { state.showFriends.toggle() }
    @objc func toggleRoaming() { state.roaming.toggle() }
    @objc func playDailyAction(_ sender: NSMenuItem) {
        guard let action = HachiwareAction(rawValue: sender.tag), action.isDaily else { return }
        desktop.playDailyAction(action)
    }
    @objc func stopDailyAction() { desktop.stopDailyAction() }
    @objc func demo(_ sender: NSMenuItem) { state.demo(Friend.developmentRoster[sender.tag]) }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { monitor.stop(); desktop?.stopCharacterVoice() }
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
