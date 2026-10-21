import Foundation

/// Reuse the existing reaction recordings without pretending they are spoken dialogue.
enum ChiikawaVoiceCue: Equatable {
    case study, eat, hug, pajamas, attack, wake

    init(_ action: ChiikawaLifeAction) {
        switch action {
        case .study: self = .study
        case .eat: self = .eat
        case .hug: self = .hug
        case .pajamas: self = .pajamas
        }
    }

    var recordingID: String {
        switch self {
        case .study, .attack: return "chiikawa-effort"
        case .eat, .hug, .pajamas, .wake: return "chiikawa-happy"
        }
    }

    static let minimumInterval: TimeInterval = 8
}

extension DesktopController {
    @discardableResult
    func playChiikawaMotionVoice(_ cue: ChiikawaVoiceCue, now: Date) -> Bool {
        guard state.chiikawaVoice, state.isVisible(.chiikawa),
              let actor = chiikawaActor, now >= actor.bubbleUntil,
              chiikawaVoice.player == nil,
              lastChiikawaVoiceStarted.map({ now.timeIntervalSince($0) >= ChiikawaVoiceCue.minimumInterval }) ?? true,
              let line = RecordingCatalog.chiikawa.clips.first(where: { $0.id == cue.recordingID }),
              chiikawaVoice.play(line, volume: state.characterVolume) else { return false }
        chiikawaAutomaticVoiceCue = cue
        lastChiikawaVoiceStarted = now
        lastChiikawaVoiceID = line.id
        return true
    }

    func stopChiikawaMotionVoice(_ cue: ChiikawaVoiceCue) {
        guard chiikawaAutomaticVoiceCue == cue else { return }
        stopChiikawaVoice()
    }
}
