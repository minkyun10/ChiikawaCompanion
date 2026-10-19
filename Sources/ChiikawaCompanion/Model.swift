import AppKit
import Combine

enum Friend: String, CaseIterable, Codable, Identifiable {
    case chiikawa, hachiware, usagi, momonga, kurimanju
    // Finish one character's behaviour before exposing the other characters.
    static let developmentRoster: [Friend] = [.hachiware]
    static let hachiwareClickQuotes = [
        "어떻게든 돼라!",
        "추억은… 계속… 있는 거니까.",
        "그치만… 기쁜 일도 가득 있었잖아!",
        "최고잖아!!",
        "이렇게나 함께 있는데, 다른 사람이 된다니 싫어.",
        "같이 합격해서, 같은 보수를 받아서, 좀 더 큰 집에 같이 살자!",
        "내가… 떨어졌어……",
        "우리가 꾼 꿈, 혹시 이어져 있었던 걸까?",
        "기분 탓이야! 기분 탓!",
        "내일도 자격증 공부 해야 하니까… 오늘은 자야지…"
    ]
    var id: String { rawValue }
    var name: String {
        switch self {
        case .chiikawa: return "치이카와"
        case .hachiware: return "하치와레"
        case .usagi: return "우사기"
        case .momonga: return "모몽가"
        case .kurimanju: return "쿠리만쥬"
        }
    }
    var greeting: String {
        switch self {
        case .chiikawa: return "와아…! 반가워!"
        case .hachiware: return Self.hachiwareClickQuotes.randomElement() ?? "오늘도 같이 있자!"
        case .usagi: return "우라! 야하!"
        case .momonga: return "나 좀 봐줘!"
        case .kurimanju: return "잠깐 쉬어 가자."
        }
    }
    var color: NSColor {
        switch self {
        case .chiikawa: return NSColor(hex: 0xEDAEBC)
        case .hachiware: return NSColor(hex: 0x7EA6B9)
        case .usagi: return NSColor(hex: 0xE8C871)
        case .momonga: return NSColor(hex: 0xA7B8D9)
        case .kurimanju: return NSColor(hex: 0xBDA38B)
        }
    }
}

struct Assignment: Codable, Identifiable {
    var friend: Friend
    var sender: String = ""
    var enabled: Bool = true
    var id: String { friend.id }
}

enum SenderMatcher {
    static func normalize(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func match(_ sender: String, in assignments: [Assignment]) -> Friend? {
        let name = normalize(sender)
        guard !name.isEmpty else { return nil }
        let matches = assignments.filter {
            $0.enabled && !normalize($0.sender).isEmpty && normalize($0.sender) == name
        }
        return matches.count == 1 ? matches[0].friend : nil
    }
    static func duplicateNames(_ assignments: [Assignment]) -> Set<String> {
        let names = assignments.filter(\.enabled).map { normalize($0.sender) }.filter { !$0.isEmpty }
        return Set(Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys)
    }
}

final class AppState: ObservableObject {
    @Published var assignments: [Assignment] { didSet { save() } }
    @Published var roaming: Bool { didSet { defaults.set(roaming, forKey: "roaming") } }
    @Published var voice: Bool { didSet { defaults.set(voice, forKey: "voice") } }
    @Published var showFriends = true
    @Published var monitoring = false
    @Published var monitoringStatus = "꺼져 있어요"
    @Published var accessibilityAvailable = false
    @Published var lastEvent = "아직 받은 알림이 없어요"
    @Published var verifiedSession = false
    @Published var enabledItems: Set<CompanionItem> {
        didSet { defaults.set(enabledItems.map(\.rawValue).sorted(), forKey: "enabledItems") }
    }
    @Published var automaticItems: Bool { didSet { defaults.set(automaticItems, forKey: "automaticItems") } }
    @Published var expressive: Bool { didSet { defaults.set(expressive, forKey: "expressive") } }
    @Published var equippedItem: CompanionItem?
    @Published var itemStatus = "바탕화면에서 소품을 찾아요"
    @Published var homeEnabled: Bool { didSet { defaults.set(homeEnabled, forKey: "homeEnabled") } }
    @Published var automaticRest: Bool { didSet { defaults.set(automaticRest, forKey: "automaticRest") } }
    @Published var homeStatus = "집을 클릭하면 쉬러 가요"
    @Published var resting = false
    @Published var characterVoice: Bool {
        didSet {
            defaults.set(characterVoice, forKey: "characterVoice")
            if !characterVoice { onStopCharacterVoice?() }
        }
    }
    @Published var characterVolume: Double { didSet { defaults.set(characterVolume, forKey: "characterVolume") } }
    @Published var voiceStatus = "클릭하면 음성 4개와 명대사 10개 중 하나를 보여줘요"
    @Published var dailyActionStatus = "공부하고, 밥도 먹고, 잠깐 쉬어 가요"
    @Published var dailyActionRunning = false
    var onDailyAction: ((HachiwareAction) -> Void)?
    var onStopDailyAction: (() -> Void)?
    var onVoicePreview: (() -> Void)?
    var onStopCharacterVoice: (() -> Void)?
    var onGoHome: (() -> Void)?
    var onWake: (() -> Void)?
    var onScatterItems: (() -> Void)?
    var onSeekItem: ((CompanionItem) -> Void)?
    var onDropItem: (() -> Void)?
    var onDemo: ((Friend) -> Void)?
    var onReset: (() -> Void)?
    var onMonitoringChange: ((Bool) -> Void)?
    let defaults: UserDefaults
    var activeAssignments: [Assignment] {
        assignments.filter { Friend.developmentRoster.contains($0.friend) }
    }
    var activeAssignmentIndices: [Int] {
        assignments.indices.filter { Friend.developmentRoster.contains(assignments[$0].friend) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let restoredItems = Set((defaults.stringArray(forKey: "enabledItems") ?? CompanionItem.allCases.map(\.rawValue))
            .compactMap(CompanionItem.init(rawValue:)))
        enabledItems = restoredItems
        // Removed props cannot survive in older saved preferences.
        defaults.set(restoredItems.map(\.rawValue).sorted(), forKey: "enabledItems")
        characterVoice = defaults.object(forKey: "characterVoice") as? Bool ?? true
        // Both former modes now share a single fourteen-line click pool.
        defaults.removeObject(forKey: "recordedDialogue")
        let savedVolume = defaults.object(forKey: "characterVolume") as? Double ?? 0.65
        characterVolume = savedVolume.isFinite ? min(1, max(0, savedVolume)) : 0.65
        homeEnabled = defaults.object(forKey: "homeEnabled") as? Bool ?? true
        automaticRest = defaults.object(forKey: "automaticRest") as? Bool ?? true
        automaticItems = defaults.object(forKey: "automaticItems") as? Bool ?? true
        expressive = defaults.object(forKey: "expressive") as? Bool ?? true
        if let data = defaults.data(forKey: "assignments"),
           let saved = try? JSONDecoder().decode([Assignment].self, from: data) {
            assignments = Friend.allCases.map { friend in
                saved.first(where: { $0.friend == friend }) ?? Assignment(friend: friend)
            }
        } else {
            assignments = Friend.allCases.map { Assignment(friend: $0) }
        }
        roaming = defaults.object(forKey: "roaming") as? Bool ?? true
        voice = defaults.bool(forKey: "voice")
        if !defaults.bool(forKey: "hachiwareWalkStage") {
            if let index = assignments.firstIndex(where: { $0.friend == .hachiware }) {
                assignments[index].enabled = true
            }
            roaming = true
            defaults.set(true, forKey: "hachiwareWalkStage")
            defaults.set(true, forKey: "roaming")
            save()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(assignments) else { return }
        defaults.set(data, forKey: "assignments")
    }
    func demo(_ friend: Friend) { onDemo?(friend) }
    func setMonitoring(_ enabled: Bool) {
        monitoring = enabled
        onMonitoringChange?(enabled)
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
}
