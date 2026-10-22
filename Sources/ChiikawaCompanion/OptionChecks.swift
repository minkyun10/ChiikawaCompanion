import AppKit

extension SelfTest {
    static func runSimpleOptionChecks(check:(Bool,String)->Void) {
        let suite="SimpleOptions-\(UUID().uuidString)",defaults=UserDefaults(suiteName:suite)!
        defer {defaults.removePersistentDomain(forName:suite)}
        let state=AppState(defaults:defaults)
        for friend in Friend.developmentRoster {
            let others=Dictionary(uniqueKeysWithValues:Friend.developmentRoster.filter{$0 != friend}.map{($0,state.itemsEnabled(for:$0))})
            state.setItemsEnabled(false,for:friend)
            check(!state.itemsEnabled(for:friend),"\(friend.name): one master switch disables all owned props")
            let reopened=AppState(defaults:defaults)
            check(!reopened.itemsEnabled(for:friend),"\(friend.name): master item off survives reopening")
            state.setItemsEnabled(true,for:friend)
            check(state.itemsEnabled(for:friend) && others.allSatisfy{state.itemsEnabled(for:$0.key)==$0.value},"\(friend.name): restoring items preserves every other owner")
            if friend.isExpansion {
                check(state.options(for:friend).items == Set(RosterItemKind.available(for:friend)),"\(friend.name): master switch restores only the allowed items")
            }
            var previews=0
            state.onVoicePreview={previews+=1};state.onChiikawaVoicePreview={previews+=1}
            state.onRosterCommand={owner,command in if case .voicePreview=command,owner==friend {previews+=1}}
            state.previewVoice(for:friend)
            check(previews == (state.hasVoice(for:friend) ? 1:0),"\(friend.name): voice button routes to its own verified recording only")
        }
        state.walkingFriends=[];state.roaming=false;state.showFriends=false
        state.setSummoned(true,friend:.kani)
        check(state.isVisible(.kani) && state.isWalking(.kani),"summoning resumes the selected friend's walk without resetting positions")
        state.setSummoned(false,friend:.kani)
        check(!state.isVisible(.kani),"summoning switch also hides the selected friend")
    }
}
