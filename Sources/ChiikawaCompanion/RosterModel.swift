import AppKit

extension Friend {
    static let expansionOrder: [Friend] = [.usagi, .kurimanju, .momonga]
    var isExpansion: Bool { Self.expansionOrder.contains(self) }
    var canvasSize: NSSize { self == .usagi ? NSSize(width: 256, height: 360) : NSSize(width: 256, height: 256) }
    var actorSize: NSSize { self == .usagi ? NSSize(width: 132, height: 210) : NSSize(width: 132, height: 150) }
    var voiceActor: String {
        switch self { case .usagi: return "권다예"; case .kurimanju: return "원종준"; case .momonga: return "미소"; default: return "" }
    }
    var reactionTexts: [String] {
        switch self {
        case .usagi: return ["야하!", "우라!", "하아?", "푸루루루!", "야하하!", "우랴!", "하!", "야하~", "우라라!", "풋!"]
        case .kurimanju: return ["크아~", "후우…", "한입 더.", "잠깐 쉬자.", "천천히…", "좋군.", "음~", "같이 먹자.", "잘 먹었다.", "오늘도 수고했어."]
        case .momonga: return ["나 좀 봐!", "귀엽다고 해!", "칭찬해 줘!", "기다렸어?", "더 보고 있어!", "나도 줘!", "한 번 더!", "잘 봤지?", "쓰다듬어 줘!", "여기 있어!"]
        default: return []
        }
    }
    var weaponName: String { self == .usagi ? "노란 토벌봉" : "공용 훈련봉" }
}

enum RosterItemKind: String, CaseIterable, Codable, Identifiable {
    case camera, weapon, keepsake
    var id: String { rawValue }
    var symbol: String { switch self { case .camera: return "camera"; case .weapon: return "sparkles"; case .keepsake: return "star" } }
    func name(for friend: Friend) -> String {
        switch self {
        case .camera: return "카메라"
        case .weapon: return friend.weaponName
        case .keepsake: return friend == .usagi ? "푸딩" : friend == .kurimanju ? "간식과 컵" : "벚꽃"
        }
    }
}

struct RosterProp: DesktopProp, Identifiable {
    let owner: Friend
    let kind: RosterItemKind
    var rawValue: String { owner.rawValue + ":" + kind.rawValue }
    var id: String { rawValue }
    init(owner: Friend, kind: RosterItemKind) { self.owner = owner; self.kind = kind }
    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":")
        guard parts.count == 2, let owner = Friend(rawValue: String(parts[0])), owner.isExpansion,
              let kind = RosterItemKind(rawValue: String(parts[1])) else { return nil }
        self.init(owner: owner, kind: kind)
    }
    static var allCases: [Self] { Friend.expansionOrder.flatMap { friend in RosterItemKind.allCases.map { Self(owner: friend, kind: $0) } } }
    var name: String { "\(owner.name) \(kind.name(for: owner))" }
    var spawnFraction: (CGFloat, CGFloat) {
        let index = CGFloat(Friend.expansionOrder.firstIndex(of: owner) ?? 0)
        switch kind { case .camera: return (0.17 + index * 0.10, 0.55)
        case .weapon: return (0.57 + index * 0.07, 0.74); case .keepsake: return (0.38 + index * 0.10, 0.18) }
    }
    func draw(in rect: NSRect) { RosterItemArtwork.draw(kind, friend: owner, in: rect) }
}

struct RosterOptions: Codable, Equatable {
    var items = Set(RosterItemKind.allCases)
    var automaticItems = true
    var automaticRest = true
    var voice = true

    private enum CodingKeys: String, CodingKey {
        case items, automaticItems, automaticRest, voice
    }
    init() {}
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Decode names first so an old guitar does not discard the owner's other settings.
        if let names = try values.decodeIfPresent(Set<String>.self, forKey: .items) {
            items = Set(names.compactMap(RosterItemKind.init(rawValue:)))
        }
        automaticItems = try values.decodeIfPresent(Bool.self, forKey: .automaticItems) ?? automaticItems
        automaticRest = try values.decodeIfPresent(Bool.self, forKey: .automaticRest) ?? automaticRest
        voice = try values.decodeIfPresent(Bool.self, forKey: .voice) ?? voice
    }
}

struct RosterStatus: Equatable {
    var equipped: RosterItemKind?
    var item = "바탕화면 소품을 찾아요"
    var action = "산책하고 소품과 놀아요"
    var actionRunning = false
    var home = "공용 집에서 함께 쉴 수 있어요"
    var resting = false
    var voice = "클릭할 때만 녹음을 재생해요"
}

enum RosterCommand {
    case seek(RosterItemKind), drop, scatter, action(RosterAction), stopAction
    case home, wake, voicePreview, stopVoice
}

enum RosterAction: String, CaseIterable {
    case wave, laugh, surprised, pickup, camera, attack, sleep, wake, keepsake
    var title: String {
        switch self {
        case .wave: return "인사하기"; case .laugh: return "웃기"; case .surprised: return "놀라기"; case .pickup: return "줍기"
        case .camera: return "사진 찍기"; case .attack: return "무기 휘두르기"
        case .sleep: return "잠자기"; case .wake: return "일어나기"; case .keepsake: return "소품과 놀기"
        }
    }
    static let selectable: [Self] = [.camera, .keepsake]
    var duration: TimeInterval { self == .wake ? 0.96 : 2.4 }
    var cycle: TimeInterval { self == .attack ? 1.2 : self == .wake ? 0.96 : self == .pickup ? 0.65 : 2.4 }
}

struct RosterVisual {
    var action: RosterAction?
    var elapsed: TimeInterval = 0
    var equipped: RosterItemKind?
    var happy = false
}

extension AppState {
    func options(for friend: Friend) -> RosterOptions { rosterOptions[friend] ?? RosterOptions() }
    func status(for friend: Friend) -> RosterStatus { rosterStatuses[friend] ?? RosterStatus() }
    func updateOptions(_ friend: Friend, _ change: (inout RosterOptions) -> Void) {
        var next = options(for: friend); change(&next); rosterOptions[friend] = next
        if !next.voice { onRosterCommand?(friend, .stopVoice) }
    }
    func publish(_ friend: Friend, _ next: RosterStatus) {
        if status(for: friend) != next { rosterStatuses[friend] = next }
    }
}
