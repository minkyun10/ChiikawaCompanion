import AppKit
import ApplicationServices
import CryptoKit

struct KakaoNotification: Equatable {
    let sender: String
    // Preview text exists only in memory for the matching notification's brief display.
    let body: String?
    // The deduplicator retains only this hash, never message text.
    let fingerprint: String
}

struct KakaoAlertPresentation {
    let title: String
    let message: String
    let spokenText: String

    init(sender: String, body: String?, demo: Bool = false) {
        let prefix = demo ? "[시연] " : ""
        title = prefix + sender
        let preview = body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        message = preview.isEmpty ? "알림 미리보기에 메시지 내용이 없어요."
            : String(preview.prefix(500)) + (preview.count > 500 ? "…" : "")
        // Existing voice alerts announce the sender; private message contents are not spoken.
        spokenText = "\(prefix)\(sender)한테 카톡 왔어!"
    }
}

struct NotificationText {
    var identifier: String = ""
    var text: String
}

enum KakaoNotificationParser {
    static let appNames: Set<String> = ["카카오톡", "KakaoTalk"]
    static func isApp(_ text: String) -> Bool { appNames.contains(SenderMatcher.normalize(text)) }

    static func parse(app: String, title: String?, texts: [NotificationText], summary: String?) -> KakaoNotification? {
        guard isApp(app) else { return nil }
        let leaves = texts.filter {
            !$0.identifier.lowercased().contains("time") && !SenderMatcher.normalize($0.text).isEmpty
        }
        var sender = title.map(SenderMatcher.normalize) ?? ""
        var body = ""
        let explicitBody = leaves.filter {
            let id = $0.identifier.lowercased()
            return !id.contains("title") && (id.contains("body") || id.contains("message"))
        }.map(\.text).joined(separator: "\n")
        func summaryParts(_ summary: String) -> [String] {
            summary.split(maxSplits: 2, omittingEmptySubsequences: false,
                          whereSeparator: { $0 == "," || $0 == "\n" }).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if !sender.isEmpty && !isApp(sender) {
            if let i = leaves.firstIndex(where: { SenderMatcher.normalize($0.text) == sender }), i + 1 < leaves.count {
                body = explicitBody.isEmpty ? leaves.dropFirst(i + 1).map(\.text).joined(separator: "\n") : explicitBody
            } else if !explicitBody.isEmpty {
                body = explicitBody
            } else if let summary {
                let parts = summaryParts(summary)
                if parts.count == 3, isApp(parts[0]), SenderMatcher.normalize(parts[1]) == sender { body = parts[2] }
            }
        } else if let i = leaves.firstIndex(where: { isApp($0.text) }), i + 1 < leaves.count {
            sender = SenderMatcher.normalize(leaves[i + 1].text)
            if i + 2 < leaves.count {
                body = explicitBody.isEmpty ? leaves.dropFirst(i + 2).map(\.text).joined(separator: "\n") : explicitBody
            }
        } else if let summary {
            let parts = summaryParts(summary)
            guard parts.count >= 2, isApp(parts[0]) else { return nil }
            sender = parts[1]
            body = parts.count > 2 ? parts[2] : ""
        } else { return nil }
        guard !sender.isEmpty, !isApp(sender), sender.count <= 100 else { return nil }
        let digest = SHA256.hash(data: Data((app + "\u{0}" + sender + "\u{0}" + body).utf8))
            .map { String(format: "%02x", $0) }.joined()
        let preview = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return KakaoNotification(sender: sender, body: preview.isEmpty ? nil : String(preview.prefix(2000)), fingerprint: digest)
    }
}

struct NotificationDeduplicator {
    private var seeded = false
    private var seen: [String: Date] = [:]
    mutating func reset() { seeded = false; seen.removeAll() }
    mutating func fresh(_ events: [KakaoNotification], now: Date) -> [KakaoNotification] {
        seen = seen.filter { now.timeIntervalSince($0.value) < 1800 }
        let baseline = !seeded
        seeded = true
        var result: [KakaoNotification] = []
        for event in events {
            let isNew = seen[event.fingerprint] == nil
            seen[event.fingerprint] = now
            if isNew && !baseline { result.append(event) }
        }
        if seen.count > 1024 {
            seen = Dictionary(uniqueKeysWithValues: seen.sorted { $0.value > $1.value }.prefix(512).map { ($0.key, $0.value) })
        }
        return result
    }
}

private struct AccessibilityNode {
    var role: String
    var identifier: String
    var title: String
    var description: String
    var value: String
    var children: [AccessibilityNode]
    var leafTexts: [NotificationText] {
        let own = role == "AXStaticText" && !value.isEmpty ? [NotificationText(identifier: identifier, text: value)] : []
        return own + children.flatMap(\.leafTexts)
    }
    var candidates: [KakaoNotification] {
        // Prefer the smallest notification group. Never match against a whole window's combined text.
        let nested = children.flatMap(\.candidates)
        if !nested.isEmpty { return nested }
        guard role == "AXGroup" || role == "AXButton" else { return [] }
        let texts = leafTexts
        let summaries = [description, title].filter { !$0.isEmpty }
        var app: String?
        for summary in summaries {
            let first = summary.components(separatedBy: CharacterSet(charactersIn: ",\n")).first ?? ""
            if KakaoNotificationParser.isApp(first) { app = SenderMatcher.normalize(first); break }
        }
        if app == nil, let header = texts.first, KakaoNotificationParser.isApp(header.text) {
            app = header.text
        }
        guard let app else { return [] }
        // Require an explicit title, app-label + next text, or app-prefixed summary.
        // A sender's name merely mentioned in the message body is never searched for.
        let explicitTitle = texts.first {
            $0.identifier.lowercased().contains("title") && !KakaoNotificationParser.isApp($0.text)
                && !$0.identifier.lowercased().contains("subtitle")
        }?.text
        guard let event = KakaoNotificationParser.parse(app: app, title: explicitTitle, texts: texts,
                                                      summary: summaries.first(where: {
            KakaoNotificationParser.isApp($0.components(separatedBy: CharacterSet(charactersIn: ",\n")).first ?? "")
        })) else { return [] }
        return [event]
    }
}

final class KakaoNotificationMonitor {
    var onNotification: ((KakaoNotification) -> Void)?
    var onStatus: ((String) -> Void)?
    var onAccessChange: ((Bool) -> Void)?
    private let queue = DispatchQueue(label: "local.chiikawa.notification-reader", qos: .utility)
    private var source: DispatchSourceTimer?
    private var generation = 0
    private var deduplicator = NotificationDeduplicator()
    private var lastStatus = ""
    static var hasPermission: Bool { AXIsProcessTrustedWithOptions(nil) }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            self.source?.cancel()
            self.generation += 1
            let token = self.generation
            self.deduplicator.reset(); self.lastStatus = ""
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: 1.5, leeway: .milliseconds(150))
            timer.setEventHandler { [weak self] in self?.scan(token: token) }
            self.source = timer; timer.resume()
        }
    }
    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.generation += 1
            self.source?.cancel(); self.source = nil
            self.deduplicator.reset()
        }
    }
    private func status(_ text: String, token: Int) {
        guard lastStatus != text else { return }
        lastStatus = text
        DispatchQueue.main.async { [weak self] in self?.onStatus?(text) }
    }
    private func scan(token: Int) {
        guard token == generation else { return }
        // The user explicitly enabled monitoring. Try the authorized read itself;
        // an OS denial is authoritative, rather than relying only on a preflight Boolean.
        guard let process = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else {
            status("macOS 알림을 기다리는 중이에요", token: token); return
        }
        let app = AXUIElementCreateApplication(process.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.12)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else {
            DispatchQueue.main.async { [weak self] in self?.onAccessChange?(false) }
            if result == .apiDisabled {
                status("손쉬운 사용 권한이 필요해요", token: token)
                deduplicator.reset()
            } else {
                status("알림 화면에 접근할 수 없어요 (\(result.rawValue))", token: token)
            }
            return
        }
        DispatchQueue.main.async { [weak self] in self?.onAccessChange?(true) }
        var budget = 550
        let deadline = Date().addingTimeInterval(0.35)
        var events: [KakaoNotification] = []
        for window in windows {
            if let root = read(window, depth: 0, budget: &budget, deadline: deadline) {
                events += root.candidates
            }
        }
        status("알림 감지 중 · 실제 카톡 수신으로 확인해 주세요", token: token)
        for event in deduplicator.fresh(events, now: Date()) {
            DispatchQueue.main.async { [weak self] in self?.onNotification?(event) }
        }
    }
    private func attribute(_ element: AXUIElement, _ key: String) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return "" }
        return value as? String ?? ""
    }
    private func read(_ element: AXUIElement, depth: Int, budget: inout Int, deadline: Date) -> AccessibilityNode? {
        guard budget > 0, depth < 14, Date() < deadline else { return nil }
        budget -= 1
        let role = attribute(element, kAXRoleAttribute)
        var node = AccessibilityNode(role: role, identifier: attribute(element, "AXIdentifier"),
                                     title: attribute(element, kAXTitleAttribute),
                                     description: attribute(element, kAXDescriptionAttribute),
                                     value: role == "AXStaticText" ? attribute(element, kAXValueAttribute) : "", children: [])
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
           let children = value as? [AXUIElement] {
            for child in children {
                if let nested = read(child, depth: depth + 1, budget: &budget, deadline: deadline) { node.children.append(nested) }
            }
        }
        return node
    }
}
