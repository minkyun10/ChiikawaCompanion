import AppKit

extension SelfTest {
    static func runChiikawaMotionVoiceChecks(check: (Bool, String) -> Void) {
        let suite = "ChiikawaMotionVoiceChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        state.roaming = false; state.expressive = true; state.characterVoice = true; state.chiikawaVoice = true
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.automaticActivities = false; state.chiikawaAutomaticActivities = false
        state.automaticRest = false; state.chiikawaAutomaticRest = false
        state.characterVolume = 0.27
        // Decode real bundled recordings but never send self-test audio to the speakers.
        var starts = 0
        let voice = RecordedVoicePlayer(startPlayback: { _ in starts += 1; return true })
        let hachiVoice = RecordedVoicePlayer(startPlayback: { _ in true })
        let desktop = DesktopController(state: state, startTimer: false, recordedVoice: hachiVoice, chiikawaVoice: voice)
        let actor = desktop.chiikawaActor!, now = Date(), away = NSPoint(x: -10000, y: -10000)
        func date(_ offset: Double) -> Date { now.addingTimeInterval(offset) }
        func tick(_ offset: Double, hover: Bool = false) {
            desktop.tick(now: date(offset), pointer: hover ? NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY) : away,
                         pointerCanReachCharacter: true)
        }
        func finish() {
            if let player = voice.player { voice.audioPlayerDidFinishPlaying(player, successfully: true) }
        }
        defer {
            voice.stop(); hachiVoice.stop()
            desktop.actors.forEach { $0.dismissBubble(); $0.panel.orderOut(nil); $0.attackOverlay.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil); desktop.chiikawaDesk.panel.orderOut(nil); desktop.chiikawaFood.panel.orderOut(nil)
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
        }
        check(ChiikawaLifeAction.allCases.allSatisfy { action in
            RecordingCatalog.chiikawa.clips.contains { $0.id == ChiikawaVoiceCue(action).recordingID }
        } && ChiikawaVoiceCue.attack.recordingID == "chiikawa-effort" && ChiikawaVoiceCue.wake.recordingID == "chiikawa-happy",
              "all six voiced motions resolve to existing effort or happy reaction recordings")
        let hachiLine = RecordingCatalog.shared.clips[0]
        hachiVoice.play(hachiLine, volume: 0.3)
        desktop.playChiikawaLife(.study, now: date(0))
        check(starts == 1 && voice.currentID == "chiikawa-effort" && desktop.chiikawaAutomaticVoiceCue == .study
              && actor.view.chiikawaLife == .study && actor.bubble == nil,
              "study starts one effort clip without replacing the animation with click dialogue")
        check(abs((voice.player?.volume ?? -1) - 0.27) < 0.001 && hachiVoice.currentID == hachiLine.id,
              "motion audio uses the shared volume without replacing Hachiware's player")
        tick(0.1); tick(0.5); tick(1)
        check(starts == 1 && desktop.chiikawaLifeRoutine.selected == .study,
              "repeated animation ticks never restart or repeat a motion recording")
        desktop.stopChiikawaLife()
        check(voice.player == nil && desktop.chiikawaAutomaticVoiceCue == nil,
              "cancelling study stops only its associated automatic voice")
        desktop.playChiikawaLife(.eat, now: date(1.1))
        check(starts == 1 && voice.player == nil && actor.view.chiikawaLife == .eat,
              "rapid action changes still animate but respect the eight-second audio interval")
        desktop.stopChiikawaLife()
        desktop.playChiikawaLife(.eat, now: date(9))
        check(starts == 2 && voice.currentID == "chiikawa-happy" && actor.bubble == nil,
              "eating selects a happy reaction at the beginning of the meal")
        state.characterVolume = 0.43; tick(9.1)
        check(abs((voice.player?.volume ?? -1) - 0.43) < 0.001,
              "changing the shared volume updates automatic audio already in progress")
        state.chiikawaVoice = false
        check(voice.player == nil && hachiVoice.currentID == hachiLine.id,
              "the Chiikawa voice switch immediately stops motion audio and preserves Hachiware audio")
        state.chiikawaVoice = true; tick(9.2)
        check(starts == 2, "unmuting partway through a motion does not start a delayed recording")
        desktop.stopChiikawaLife(); state.chiikawaVoice = false
        desktop.playChiikawaLife(.study, now: date(18))
        check(starts == 2 && actor.view.chiikawaLife == .study,
              "muted actions keep their animation while remaining silent")
        desktop.stopChiikawaLife(); state.chiikawaVoice = true
        desktop.playChiikawaLife(.hug, now: date(18.1))
        check(starts == 3 && voice.currentID == "chiikawa-happy" && desktop.chiikawaAutomaticVoiceCue == .hug,
              "hugging uses a happy reaction and muted events do not consume the interval")
        finish()
        check(voice.player == nil && desktop.chiikawaAutomaticVoiceCue == nil && desktop.chiikawaLifeRoutine.selected == .hug,
              "natural audio completion releases its context without cancelling the hug")
        desktop.stopChiikawaLife(); desktop.playChiikawaLife(.pajamas, now: date(27))
        check(starts == 4 && voice.currentID == "chiikawa-happy" && actor.view.chiikawaLife == .pajamas,
              "dressing starts a happy clip while preserving the twelve-frame animation")
        desktop.stopChiikawaLife()
        tick(35)
        let body = NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY)
        _ = desktop.receiveChiikawaItem(.pinkSasumata, at: body, now: date(35))
        tick(36, hover: true)
        check(starts == 5 && voice.currentID == "chiikawa-effort" && actor.view.action == .attack,
              "armed hover starts one effort clip with the first attack frame")
        tick(36.6, hover: true); tick(38, hover: true)
        check(starts == 5 && actor.view.action == .attack,
              "looping the attack animation does not loop its voice")
        tick(38.1)
        check(voice.player == nil && actor.view.action == nil, "leaving armed hover immediately stops attack audio")
        tick(39, hover: true); tick(47, hover: true)
        check(starts == 5 && actor.view.action == .attack,
              "a throttled hover stays silent even when the interval expires mid-attack")
        tick(47.1); tick(47.2, hover: true)
        check(starts == 6 && voice.currentID == "chiikawa-effort", "a fresh hover after the interval can speak again")
        state.expressive = false; tick(47.3, hover: true)
        check(voice.player == nil && actor.view.action == nil, "disabling attack expressions also stops the matching voice")
        state.expressive = true; tick(55)
        desktop.sayChiikawa(now: date(56))
        let clickID = voice.currentID
        check(starts == 7 && clickID != nil && !desktop.playChiikawaMotionVoice(.attack, now: date(56.1))
              && voice.currentID == clickID && actor.bubble != nil,
              "click dialogue takes priority and an automatic cue cannot replace its recording or bubble")
        finish(); actor.dismissBubble()
        check(!desktop.playChiikawaMotionVoice(.attack, now: date(56.5)) && starts == 7,
              "recent click playback also delays automatic audio after the click clip ends")
        desktop.playChiikawaLife(.study, now: date(65)); actor.view.onDragStart?()
        check(starts == 8 && voice.player == nil && desktop.chiikawaLifeRoutine.selected == nil,
              "dragging cancels the current motion and its voice together")
        desktop.playChiikawaLife(.eat, now: date(74)); state.visibleFriends.remove(.chiikawa); tick(74.1)
        check(starts == 9 && voice.player == nil && desktop.chiikawaAutomaticVoiceCue == nil,
              "hiding Chiikawa clears active automatic playback")
        check(!desktop.playChiikawaMotionVoice(.eat, now: date(83)), "hidden Chiikawa cannot start automatic audio")
        state.visibleFriends.insert(.chiikawa); tick(83)
        desktop.goChiikawaHome(now: date(83.1))
        desktop.chiikawaSeekingHomeKey = false; desktop.chiikawaWorld.requested = nil
        actor.panel.setFrameOrigin(ItemWorld.destination(for: desktop.home.entrance)); tick(83.2); tick(84.2)
        check(desktop.chiikawaHomeRoutine.isInside && voice.player == nil && starts == 9,
              "entering the house and sleeping stay silent")
        desktop.wakeChiikawa(now: date(84.3), animated: true)
        desktop.wakeChiikawa(now: date(84.4), animated: true); tick(84.5)
        check(starts == 10 && voice.currentID == "chiikawa-happy" && desktop.chiikawaAutomaticVoiceCue == .wake
              && desktop.chiikawaWakingAt != nil && actor.bubble == nil,
              "waking speaks once with the stretch animation even though the walking panel is hidden")
        tick(85.4)
        check(voice.currentID == "chiikawa-happy" && desktop.chiikawaWakingAt == nil && actor.panel.isVisible,
              "finishing the shorter wake animation does not truncate the reaction recording")
        state.visibleFriends.remove(.chiikawa); tick(85.5)
        check(voice.player == nil && hachiVoice.currentID == hachiLine.id,
              "all automatic voice paths leave the other character's audio untouched")
        state.chiikawaVoice = false
        let saved = AppState(defaults: defaults)
        check(!saved.chiikawaVoice && abs(saved.characterVolume - 0.43) < 0.001,
              "the same existing voice and volume preferences persist for click and motion playback")
    }
}
