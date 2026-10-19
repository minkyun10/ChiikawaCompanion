import AppKit
import AVFoundation

extension SelfTest {
    static func runVoiceChecks(defaults: UserDefaults, check: (Bool, String) -> Void) {
        let catalog = RecordingCatalog.shared
        check(catalog.isValid && catalog.clips.count == 4,
              "four real spoken excerpts and their matching captions load from local resources")
        check(catalog.clips.allSatisfy { line in
            guard let url = line.resourceURL, let audio = try? AVAudioPlayer(contentsOf: url) else { return false }
            return abs(audio.duration - line.duration) < 0.08 && audio.duration > 0.5 && audio.duration < 4
        }, "every bundled recording decodes and preserves its caption timing")
        check(!RecordingCatalog.safeFile("../outside.m4a") && !RecordingCatalog.safeFile("nested/file.m4a")
              && RecordingCatalog.resourceURL(file: "missing-voice.m4a") == nil,
              "missing or invalid audio paths cannot escape the bundled voice directory")
        check(catalog.clips.allSatisfy { previous in
            (0..<20).allSatisfy { _ in catalog.choose(excluding: previous.id)?.id != previous.id }
        }, "recorded dialogue varies without immediately repeating the same excerpt")
        check(Friend.hachiwareClickQuotes.count == 10 && Friend.hachiwareClickQuotes.allSatisfy { catalog.line(matching: $0) == nil },
              "the original ten quotes stay intact and are never paired with unrelated spoken words")
        check(RecordedVoicePlayer.volume(-3) == 0 && RecordedVoicePlayer.volume(5) == 1
              && abs(RecordedVoicePlayer.volume(.nan) - 0.65) < 0.0001,
              "audio gain clamps out-of-range values and safely handles invalid saved volume")

        // Decode the real files while replacing only the output-device start call.
        // Self-tests must never make the user's speakers play fixture audio.
        let voice = RecordedVoicePlayer(startPlayback: { _ in true })
        let first = catalog.clips[0], second = catalog.clips[1]
        check(voice.play(first, volume: 0.4) && voice.currentID == first.id,
              "a recording prepares a single player at the requested volume")
        let previous = voice.player!
        check(voice.play(second, volume: 0.7) && voice.currentID == second.id
              && voice.player !== previous && previous.delegate == nil,
              "rapid clicks replace and release the previous recording instead of overlapping audio")
        let broken = RecordedLine(id: "broken", text: "fixture", file: "missing-voice.m4a", duration: 1)
        check(!voice.play(broken, volume: 1) && voice.player == nil && voice.currentID == nil,
              "a missing clip clears old playback and fails without silently retaining stale audio")
        let failedStart = RecordedVoicePlayer(startPlayback: { _ in false })
        check(!failedStart.play(first, volume: 1) && failedStart.player == nil,
              "an output-device failure releases the prepared player")

        let state = AppState(defaults: defaults)
        state.voice = false; state.characterVoice = true; state.recordedDialogue = true
        let desktop = DesktopController(state: state, startTimer: false, recordedVoice: voice)
        let actor = desktop.actors[0]
        func bubbleText() -> String? {
            (actor.bubble?.contentView?.subviews.last as? NSTextField)?.stringValue
        }
        actor.view.onClick?()
        check(catalog.clips.first { $0.id == voice.currentID }?.text == bubbleText() && voice.player != nil,
              "the real character click callback speaks exactly the caption shown in its bubble")
        let lastID = voice.currentID
        actor.view.onClick?()
        check(voice.currentID != lastID && catalog.clips.first { $0.id == voice.currentID }?.text == bubbleText(),
              "another click chooses a new matched recording and replaces the current bubble")
        state.characterVoice = false
        check(voice.player == nil, "turning off click voice stops current playback immediately")
        actor.view.onClick?()
        check(voice.player == nil && catalog.clips.contains { $0.text == bubbleText() },
              "muted character clicks still show a recorded-line caption without playing sound")
        state.recordedDialogue = false
        actor.view.onClick?()
        check(voice.player == nil && Friend.hachiwareClickQuotes.contains(bubbleText() ?? ""),
              "the original ten-quote mode keeps its own text and does not play a mismatched excerpt")
        state.recordedDialogue = true; state.characterVoice = true
        actor.view.onClick?()
        desktop.notify(.hachiware, sender: "테스트 친구", body: "음성 중단 시연", demo: true)
        check(voice.player == nil && (bubbleText()?.contains("음성 중단 시연") ?? false),
              "an incoming notification interrupts recorded dialogue and displays its own preview")
        actor.dismissBubble(); actor.panel.orderOut(nil); desktop.home.panel.orderOut(nil)
        state.characterVoice = false; state.recordedDialogue = false; state.characterVolume = 0.24
        let reopened = AppState(defaults: defaults)
        check(!reopened.characterVoice && !reopened.recordedDialogue && abs(reopened.characterVolume - 0.24) < 0.001
              && !reopened.voice && reopened.assignments.map(\.sender) == state.assignments.map(\.sender),
              "voice mode and volume persist independently from Kakao voice and sender assignments")
        if Bundle.main.bundlePath.hasSuffix(".app") {
            check(catalog.clips.allSatisfy { $0.resourceURL?.path.hasPrefix(Bundle.main.resourcePath ?? "missing") == true },
                  "the packaged app plays its own bundled recordings without relying on Downloads or network access")
        }
    }
}
