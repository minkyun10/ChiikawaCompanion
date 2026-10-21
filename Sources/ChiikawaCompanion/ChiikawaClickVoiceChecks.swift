import AppKit

extension SelfTest {
    static func runChiikawaClickVoiceChecks(check: (Bool, String) -> Void) {
        let suite = "ChiikawaClickVoiceChecks-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        state.roaming = false; state.expressive = true; state.chiikawaVoice = true
        state.automaticItems = false; state.chiikawaAutomaticItems = false
        state.automaticActivities = false; state.chiikawaAutomaticActivities = false
        state.automaticRest = false; state.chiikawaAutomaticRest = false
        // Keep voice enabled to detect accidental automatic playback, without using the speakers.
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
        defer {
            voice.stop(); hachiVoice.stop()
            desktop.actors.forEach { $0.dismissBubble(); $0.panel.orderOut(nil); $0.attackOverlay.panel.orderOut(nil) }
            desktop.home.panel.orderOut(nil); desktop.chiikawaDesk.panel.orderOut(nil); desktop.chiikawaFood.panel.orderOut(nil)
            desktop.desktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.chiikawaDesktopItems.values.forEach { $0.panel.orderOut(nil) }
            desktop.desktopActivitySpots.values.forEach { $0.panel.orderOut(nil) }
        }
        let hachiLine = RecordingCatalog.shared.clips[0]
        hachiVoice.play(hachiLine, volume: 0.3)
        for (index, action) in ChiikawaLifeAction.allCases.enumerated() {
            let offset = Double(index) * 10
            desktop.playChiikawaLife(action, now: date(offset)); tick(offset + 0.2)
            check(starts == 0 && voice.player == nil && actor.view.chiikawaLife == action,
                  "\(action.rawValue) animates silently even when Chiikawa click voice is enabled")
            desktop.stopChiikawaLife()
        }
        tick(40, hover: true); tick(41)
        check(starts == 0 && voice.player == nil, "ordinary hover and walking never trigger Chiikawa audio")
        _ = desktop.receiveChiikawaItem(.pinkSasumata, at: NSPoint(x: actor.panel.frame.midX, y: actor.panel.frame.midY), now: date(42))
        tick(42, hover: true); tick(54, hover: true); tick(55); tick(56, hover: true)
        check(starts == 0 && actor.view.action == .attack && voice.player == nil,
              "armed hover, attack loops and renewed hover all stay silent")
        tick(57)
        state.chiikawaAutomaticActivities = true
        for (index, spot) in [ActivitySpot.desk, .rice].enumerated() {
            let offset = 60.0 + Double(index) * 10
            actor.panel.setFrameOrigin(ItemWorld.destination(for: desktop.chiikawaStudyWorld.positions[spot]!)); tick(offset)
            check(starts == 0 && voice.player == nil && actor.view.chiikawaLife == (spot == .desk ? .study : .eat),
                  "automatic \(spot.rawValue) proximity starts the animation without sound")
            desktop.stopChiikawaLife()
        }
        state.chiikawaAutomaticActivities = false
        desktop.goChiikawaHome(now: date(80))
        desktop.chiikawaSeekingHomeKey = false; desktop.chiikawaWorld.requested = nil
        actor.panel.setFrameOrigin(ItemWorld.destination(for: desktop.home.entrance)); tick(80.1); tick(81.1)
        desktop.wakeChiikawa(now: date(81.2), animated: true); tick(81.4)
        check(starts == 0 && voice.player == nil && desktop.chiikawaWakingAt != nil,
              "entering, sleeping and waking animations never start a recording")
        tick(82.3)
        actor.view.onClick?()
        let first = voice.currentID
        check(starts == 1 && first != nil && actor.bubble != nil,
              "the real Chiikawa click callback still plays a random bundled reaction")
        actor.view.onClick?()
        check(starts == 2 && voice.currentID != first && voice.player != nil,
              "a rapid second click immediately replaces the recording without a cooldown or repeat")
        state.chiikawaVoice = false; actor.view.onClick?()
        check(starts == 2 && voice.player == nil && actor.bubble != nil,
              "muting click voice keeps click captions available without audio")
        desktop.sayChiikawa(preview: true, now: date(83))
        check(starts == 3 && voice.player != nil,
              "the explicit voice-preview button can still play a sample while ordinary clicks are muted")
        desktop.stopChiikawaVoice()
        check(voice.player == nil && hachiVoice.currentID == hachiLine.id,
              "Chiikawa playback and stopping leave Hachiware's independent recording untouched")
    }
}
