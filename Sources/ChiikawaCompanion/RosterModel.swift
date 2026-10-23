import AppKit

extension Friend {
    static let expansionOrder: [Friend] = [.usagi, .kurimanju, .momonga, .rakko, .shisa, .kani]
    var usesNewFriendRig: Bool { self == .rakko || self == .shisa || self == .kani }
    var keepsakeActionTitle: String {
        switch self {
        case .rakko: return "파르페 먹기"
        case .shisa: return "라멘 서빙하기"
        case .kani: return "책 읽기"
        default: return "소품과 놀기"
        }
    }
    var isExpansion: Bool { Self.expansionOrder.contains(self) }
    var canUseWeapon: Bool { self == .hachiware || self == .chiikawa || self == .usagi || self == .rakko }
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
        // Original companion reactions, not quotations from the show.
        case .rakko: return ["달콤한 휴식이군.", "한입 먹어 볼까.", "잠시 쉬어 가자.", "오늘도 잘했군.", "천천히 따라오렴.", "좋은 하루군.", "디저트 시간이다.", "조금 더 걸어 볼까.", "편히 쉬어.", "다음에도 함께하자."]
        case .shisa: return ["어서 오세요!", "뜨거우니 조심하세요.", "맛있게 드세요!", "오늘도 힘낼게요!", "한 그릇 나왔어요!", "감사합니다!", "열심히 준비했어요.", "잠깐 쉬어 갈까요?", "반가워요!", "또 와 주세요!"]
        case .kani: return ["같이 읽을래?", "이 책은 어때?", "좋은 이야기가 있어.", "잠깐 펼쳐 볼까.", "천천히 읽어 봐.", "오늘도 반가워.", "다음 이야기가 궁금해.", "여기 앉아서 읽자.", "이 책을 아껴 줘.", "다음에 또 만나."]
        default: return []
        }
    }
}

enum RosterItemKind: String, CaseIterable, Codable, Identifiable {
    case weapon, keepsake
    static func available(for friend: Friend) -> [Self] {
        guard friend.isExpansion else { return [] }
        return friend.canUseWeapon ? [.weapon, .keepsake] : [.keepsake]
    }
    var id: String { rawValue }
    var symbol: String { self == .weapon ? "sparkles" : "star" }
    func name(for friend: Friend) -> String {
        switch self {
        case .weapon: return friend == .rakko ? "검과 칼집" : "노란 토벌봉"
        case .keepsake:
            switch friend {
            case .usagi: return "푸딩"
            case .kurimanju: return "간식과 컵"
            case .momonga: return "벚꽃"
            case .rakko: return "딸기 파르페"
            case .shisa: return "라멘"
            case .kani: return "헌책"
            default: return "소품"
            }
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
              let kind = RosterItemKind(rawValue: String(parts[1])), RosterItemKind.available(for: owner).contains(kind) else { return nil }
        self.init(owner: owner, kind: kind)
    }
    static var allCases: [Self] { Friend.expansionOrder.flatMap { friend in RosterItemKind.available(for: friend).map { Self(owner: friend, kind: $0) } } }
    var name: String { "\(owner.name) \(kind.name(for: owner))" }
    var spawnFraction: (CGFloat, CGFloat) {
        let index = CGFloat(Friend.expansionOrder.firstIndex(of: owner) ?? 0)
        switch kind { case .weapon: return (0.57 + index * 0.07, 0.74); case .keepsake: return (0.38 + index * 0.10, 0.18) }
    }
    func draw(in rect: NSRect) { RosterItemArtwork.draw(kind, friend: owner, in: rect) }
}

struct RosterOptions: Codable, Equatable {
    var items = Set(RosterItemKind.allCases)
    var automaticItems = true
    var automaticRest = true
    var voice = true

    func normalized(for friend: Friend) -> Self {
        var result = self
        result.items.formIntersection(RosterItemKind.available(for: friend))
        return result
    }

    private enum CodingKeys: String, CodingKey {
        case items, automaticItems, automaticRest, voice
    }
    init() {}
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Decode names first so retired items do not discard the owner's other settings.
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
    case wave, laugh, surprised, pickup, attack, sleep, wake, keepsake
    static func available(for friend: Friend) -> [Self] {
        guard friend.isExpansion else { return [] }
        return allCases.filter { $0 != .attack || friend.canUseWeapon }
    }
    var title: String {
        switch self {
        case .wave: return "인사하기"; case .laugh: return "웃기"; case .surprised: return "놀라기"; case .pickup: return "줍기"
        case .attack: return "무기 휘두르기"
        case .sleep: return "잠자기"; case .wake: return "일어나기"; case .keepsake: return "소품과 놀기"
        }
    }
    static let selectable: [Self] = [.keepsake]
    var duration: TimeInterval { self == .wake ? 0.96 : 2.4 }
    var cycle: TimeInterval { self == .attack ? 1.2 : self == .wake ? 0.96 : self == .pickup ? 0.65 : self == .sleep ? 3.6 : 2.4 }
}

struct RosterVisual {
    var action: RosterAction?
    var elapsed: TimeInterval = 0
    var equipped: RosterItemKind?
    var happy = false
}

extension AppState {
    func options(for friend: Friend) -> RosterOptions { (rosterOptions[friend] ?? RosterOptions()).normalized(for: friend) }
    func status(for friend: Friend) -> RosterStatus { rosterStatuses[friend] ?? RosterStatus() }
    func updateOptions(_ friend: Friend, _ change: (inout RosterOptions) -> Void) {
        var next = options(for: friend); change(&next); next = next.normalized(for: friend); rosterOptions[friend] = next
        if !next.voice { onRosterCommand?(friend, .stopVoice) }
    }
    func publish(_ friend: Friend, _ next: RosterStatus) {
        if status(for: friend) != next { rosterStatuses[friend] = next }
    }
}
