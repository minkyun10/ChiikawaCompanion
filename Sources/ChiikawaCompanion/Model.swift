import AppKit
import Combine

enum Friend: String, CaseIterable, Codable, Identifiable {
    case chiikawa, hachiware, usagi, momonga, kurimanju, rakko, shisa, kani
    static let developmentRoster: [Friend] = [.hachiware, .chiikawa, .usagi, .kurimanju, .momonga, .rakko, .shisa, .kani]
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
        case .rakko: return "랏코"
        case .shisa: return "시사"
        case .kani: return "카니"
        }
    }
    var greeting: String {
        switch self {
        case .chiikawa: return "와아…! 반가워!"
        case .hachiware: return Self.hachiwareClickQuotes.randomElement() ?? "오늘도 같이 있자!"
        case .usagi: return "우라! 야하!"
        case .momonga: return "나 좀 봐줘!"
        case .kurimanju: return "잠깐 쉬어 가자."
        case .rakko: return "달콤한 휴식이군."
        case .shisa: return "어서 오세요!"
        case .kani: return "같이 읽을래?"
        }
    }
    var color: NSColor {
        switch self {
        case .chiikawa: return NSColor(hex: 0xEDAEBC)
        case .hachiware: return NSColor(hex: 0x7EA6B9)
        case .usagi: return NSColor(hex: 0xE8C871)
        case .momonga: return NSColor(hex: 0xA7B8D9)
        case .kurimanju: return NSColor(hex: 0xBDA38B)
        case .rakko: return NSColor(hex: 0xD9BB7C)
        case .shisa: return NSColor(hex: 0xE6A064)
        case .kani: return NSColor(hex: 0xE8A7B6)
        }
    }
}

final class AppState: ObservableObject {
    @Published var rosterOptions: [Friend: RosterOptions] {
        didSet { if let data = try? JSONEncoder().encode(rosterOptions) { defaults.set(data, forKey: "rosterOptionsV38") } }
    }
    @Published var rosterStatuses: [Friend: RosterStatus] = [:]
    var onRosterCommand: ((Friend, RosterCommand) -> Void)?
    @Published var roaming: Bool { didSet { defaults.set(roaming, forKey: "roaming") } }
    @Published var showFriends = true
    @Published var visibleFriends: Set<Friend> {
        didSet { defaults.set(visibleFriends.map(\.rawValue).sorted(), forKey: "visibleFriends") }
    }
    @Published var walkingFriends: Set<Friend> {
        didSet { defaults.set(walkingFriends.map(\.rawValue).sorted(), forKey: "walkingFriends") }
    }
    @Published var chiikawaItems: Set<ChiikawaItem> {
        didSet { defaults.set(chiikawaItems.map(\.rawValue).sorted(), forKey: "chiikawaItems") }
    }
    @Published var chiikawaAutomaticItems: Bool {
        didSet { defaults.set(chiikawaAutomaticItems, forKey: "chiikawaAutomaticItems") }
    }
    @Published var chiikawaEquipped: ChiikawaItem?
    @Published var chiikawaItemStatus = "분홍 소품을 찾아요"
    @Published var chiikawaAutomaticRest: Bool { didSet { defaults.set(chiikawaAutomaticRest, forKey: "chiikawaAutomaticRest") } }
    @Published var chiikawaFoodEnabled: Bool { didSet { defaults.set(chiikawaFoodEnabled, forKey: "chiikawaFoodEnabled") } }
    @Published var chiikawaStudyEnabled: Bool { didSet { defaults.set(chiikawaStudyEnabled, forKey: "chiikawaStudyEnabled") } }
    @Published var chiikawaAutomaticActivities: Bool { didSet { defaults.set(chiikawaAutomaticActivities, forKey: "chiikawaAutomaticActivities") } }
    @Published var chiikawaVoice: Bool {
        didSet { defaults.set(chiikawaVoice, forKey: "chiikawaVoice"); if !chiikawaVoice { onStopChiikawaVoice?() } }
    }
    @Published var chiikawaHomeStatus = "공용 집에서 함께 쉴 수 있어요"
    @Published var chiikawaResting = false
    @Published var chiikawaLifeStatus = "공부하고, 밥 먹고, 인형을 안고 쉬어요"
    @Published var chiikawaLifeRunning = false
    @Published var chiikawaVoiceStatus = "클릭하면 이주은 성우의 짧은 반응을 들려줘요"
    var onChiikawaGoHome: (() -> Void)?
    var onChiikawaWake: (() -> Void)?
    var onChiikawaEat: (() -> Void)?
    var onChiikawaStudy: (() -> Void)?
    var onChiikawaLife: ((ChiikawaLifeAction) -> Void)?
    var onStopChiikawaLife: (() -> Void)?
    var onChiikawaVoicePreview: (() -> Void)?
    var onStopChiikawaVoice: (() -> Void)?
    var onCallFriend: ((Friend) -> Void)?
    var onChiikawaSeekItem: ((ChiikawaItem) -> Void)?
    var onChiikawaDropItem: (() -> Void)?
    var onChiikawaScatterItems: (() -> Void)?
    func isVisible(_ friend: Friend) -> Bool { showFriends && visibleFriends.contains(friend) }
    func isWalking(_ friend: Friend) -> Bool { roaming && walkingFriends.contains(friend) }
    @Published var enabledItems: Set<CompanionItem> {
        didSet { defaults.set(enabledItems.map(\.rawValue).sorted(), forKey: "enabledItems") }
    }
    @Published var automaticItems: Bool { didSet { defaults.set(automaticItems, forKey: "automaticItems") } }
    @Published var expressive: Bool { didSet { defaults.set(expressive, forKey: "expressive") } }
    @Published var equippedItem: CompanionItem?
    @Published var itemStatus = "바탕화면에서 소품을 찾아요"
    @Published var homeStyle: HomeStyle { didSet { defaults.set(homeStyle.rawValue, forKey: "homeStyle") } }
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
    @Published var activityJourneyRunning = false
    @Published var enabledActivitySpots: Set<ActivitySpot> {
        didSet { defaults.set(enabledActivitySpots.map(\.rawValue).sorted(), forKey: "enabledActivitySpots") }
    }
    @Published var automaticActivities: Bool { didSet { defaults.set(automaticActivities, forKey: "automaticActivities") } }
    var onSeekActivitySpot: ((ActivitySpot) -> Void)?
    var onDailyAction: ((HachiwareAction) -> Void)?
    var onStopDailyAction: (() -> Void)?
    var onVoicePreview: (() -> Void)?
    var onStopCharacterVoice: (() -> Void)?
    var onGoHome: (() -> Void)?
    var onWake: (() -> Void)?
    var onScatterItems: (() -> Void)?
    var onSeekItem: ((CompanionItem) -> Void)?
    var onDropItem: (() -> Void)?
    var onReset: (() -> Void)?
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let decodedRosterOptions = defaults.data(forKey: "rosterOptionsV38").flatMap { try? JSONDecoder().decode([Friend: RosterOptions].self, from: $0) } ?? [:]
        var restoredRosterOptions = decodedRosterOptions.reduce(into: [Friend: RosterOptions]()) {
            $0[$1.key] = $1.value.normalized(for: $1.key)
        }
        if !defaults.bool(forKey: "rakkoSwordV55Installed") {
            // Extend an enabled inventory once; retain an explicitly disabled
            // master switch and every existing rest/audio/visibility choice.
            if var options = restoredRosterOptions[.rakko], !options.items.isEmpty {
                options.items.insert(.weapon); restoredRosterOptions[.rakko] = options
            }
            defaults.set(true, forKey: "rakkoSwordV55Installed")
        }
        rosterOptions = restoredRosterOptions
        if let data = try? JSONEncoder().encode(restoredRosterOptions) {
            defaults.set(data, forKey: "rosterOptionsV38")
        }
        let roster = Set(Friend.developmentRoster)
        let introduced = Set(defaults.stringArray(forKey: "introducedCompanionsV38") ?? ["hachiware", "chiikawa"])
        let newlyIntroduced = roster.filter { !introduced.contains($0.rawValue) }

        visibleFriends = Set((defaults.stringArray(forKey: "visibleFriends") ?? Friend.developmentRoster.map(\.rawValue))
            .compactMap(Friend.init(rawValue:))).intersection(roster)
        walkingFriends = Set((defaults.stringArray(forKey: "walkingFriends") ?? Friend.developmentRoster.map(\.rawValue))
            .compactMap(Friend.init(rawValue:))).intersection(roster)
        var restoredChiikawaItems = Set((defaults.stringArray(forKey: "chiikawaItems") ?? ChiikawaItem.allCases.map(\.rawValue))
            .compactMap(ChiikawaItem.init(rawValue:)))
        if !defaults.bool(forKey: "chiikawaLifeV26Installed") {
            restoredChiikawaItems.formUnion([.houseKey,.stuffedToy])
            defaults.set(restoredChiikawaItems.map(\.rawValue).sorted(), forKey: "chiikawaItems")
            defaults.set(true, forKey: "chiikawaLifeV26Installed")
        }
        chiikawaItems = restoredChiikawaItems
        chiikawaAutomaticItems = defaults.object(forKey: "chiikawaAutomaticItems") as? Bool ?? true
        chiikawaAutomaticRest = defaults.object(forKey: "chiikawaAutomaticRest") as? Bool ?? true
        chiikawaFoodEnabled = defaults.object(forKey: "chiikawaFoodEnabled") as? Bool ?? true
        chiikawaStudyEnabled = defaults.object(forKey: "chiikawaStudyEnabled") as? Bool ?? true
        chiikawaAutomaticActivities = defaults.object(forKey: "chiikawaAutomaticActivities") as? Bool ?? true
        chiikawaVoice = defaults.object(forKey: "chiikawaVoice") as? Bool ?? true
        // Remove preferences belonging to the retired chat-notification integration.
        for key in ["assignments", "voice", "hachiwareWalkStage", "monitoring", "monitoringStatus", "lastEvent", "verifiedSession"] {
            defaults.removeObject(forKey: key)
        }
        enabledActivitySpots = Set((defaults.stringArray(forKey: "enabledActivitySpots") ?? ActivitySpot.allCases.map(\.rawValue))
            .compactMap(ActivitySpot.init(rawValue:)))
        automaticActivities = defaults.object(forKey: "automaticActivities") as? Bool ?? true
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
        homeStyle = defaults.string(forKey: "homeStyle").flatMap(HomeStyle.init(rawValue:)) ?? .hachiware
        defaults.removeObject(forKey: "homeEnabled")
        defaults.removeObject(forKey: "chiikawaHomeEnabled")
        automaticRest = defaults.object(forKey: "automaticRest") as? Bool ?? true
        automaticItems = defaults.object(forKey: "automaticItems") as? Bool ?? true
        expressive = defaults.object(forKey: "expressive") as? Bool ?? true
        roaming = defaults.object(forKey: "roaming") as? Bool ?? true
        visibleFriends.formUnion(newlyIntroduced)
        walkingFriends.formUnion(newlyIntroduced)
        defaults.set(roster.map(\.rawValue).sorted(), forKey: "introducedCompanionsV38")
        defaults.set(visibleFriends.map(\.rawValue).sorted(), forKey: "visibleFriends")
        defaults.set(walkingFriends.map(\.rawValue).sorted(), forKey: "walkingFriends")

    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
}
