import AppKit

extension AppState {
    func setSummoned(_ enabled: Bool, friend: Friend) {
        if enabled {
            if !showFriends {visibleFriends=[]}
            showFriends=true;roaming=true;visibleFriends.insert(friend);walkingFriends.insert(friend)
        } else {visibleFriends.remove(friend)}
    }
    func itemsEnabled(for friend: Friend) -> Bool {
        switch friend {
        case .hachiware:return !enabledItems.isEmpty || !enabledActivitySpots.isEmpty
        case .chiikawa:return !chiikawaItems.isEmpty || chiikawaStudyEnabled || chiikawaFoodEnabled
        default:return !options(for:friend).items.isEmpty
        }
    }
    func setItemsEnabled(_ enabled: Bool, for friend: Friend) {
        switch friend {
        case .hachiware:
            enabledItems=enabled ? Set(CompanionItem.allCases):[]
            enabledActivitySpots=enabled ? Set(ActivitySpot.allCases):[]
            if !enabled {onStopDailyAction?()}
        case .chiikawa:
            chiikawaItems=enabled ? Set(ChiikawaItem.allCases):[]
            chiikawaStudyEnabled=enabled;chiikawaFoodEnabled=enabled
            if !enabled {onStopChiikawaLife?()}
        default:
            updateOptions(friend){$0.items=enabled ? Set(RosterItemKind.available(for:friend)):[]}
            if !enabled {onRosterCommand?(friend,.stopAction)}
        }
    }
    func hasVoice(for friend: Friend) -> Bool {
        switch friend {
        case .hachiware:return RecordingCatalog.shared.isValid
        case .chiikawa:return RecordingCatalog.chiikawa.isValid
        default:return RosterRecordingCatalog.catalog(for:friend).isValid
        }
    }
    func previewVoice(for friend: Friend) {
        guard hasVoice(for:friend) else {return}
        switch friend {
        case .hachiware:onVoicePreview?()
        case .chiikawa:onChiikawaVoicePreview?()
        default:onRosterCommand?(friend,.voicePreview)
        }
    }
}
