import AppKit
import AVFoundation

struct RecordedLine: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let file: String
    let duration: TimeInterval

    var resourceURL: URL? { RecordingCatalog.resourceURL(file: file) }
}

struct RecordingCatalog: Decodable {
    let speaker: String
    let sourceTitle: String
    let sourceProfile: String
    let clips: [RecordedLine]
    static let fileName = "hachiware-recordings-v13.json"
    static let shared = load(fileName, speaker: "손정민")
    static let chiikawa = load("chiikawa-recordings-v26.json", speaker: "이주은")
    static func load(_ fileName: String, speaker: String) -> RecordingCatalog {
        guard let url = resourceURL(file: fileName), let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode(RecordingCatalog.self, from: data),
              result.isValid else {
            return RecordingCatalog(speaker: speaker, sourceTitle: "", sourceProfile: "", clips: [])
        }
        return result
    }
    var isValid: Bool {
        !clips.isEmpty && Set(clips.map(\.id)).count == clips.count && clips.allSatisfy {
            !$0.id.isEmpty && !$0.text.isEmpty && $0.duration > 0 && $0.duration <= 15
                && Self.safeFile($0.file) && $0.file.hasSuffix(".m4a") && $0.resourceURL != nil
        }
    }
    static func safeFile(_ file: String) -> Bool {
        !file.isEmpty && file == (file as NSString).lastPathComponent && !file.contains("..")
            && !file.contains("/") && !file.contains("\\")
    }
    static func resourceURL(file: String) -> URL? {
        guard safeFile(file) else { return nil }
        return Bundle.main.resourceURL?.appendingPathComponent("Voice").appendingPathComponent(file).existingFile
            ?? Bundle.module.url(forResource: file, withExtension: nil, subdirectory: "Resources/Voice")
    }
    func choose(excluding previous: String? = nil) -> RecordedLine? {
        let candidates = clips.filter { $0.id != previous }
        return (candidates.isEmpty ? clips : candidates).randomElement()
    }
    func line(matching text: String) -> RecordedLine? { clips.first { $0.text == text } }
}

struct ClickDialogue: Identifiable, Equatable {
    let id: String
    let text: String
    let recording: RecordedLine?

    // One entry per line gives all fourteen the same chance, rather than
    // choosing a voice/text category first and over-weighting the four clips.
    static let all: [ClickDialogue] = RecordingCatalog.shared.clips.map {
        ClickDialogue(id: "voice-\($0.id)", text: $0.text, recording: $0)
    } + Friend.hachiwareClickQuotes.enumerated().map {
        ClickDialogue(id: "quote-\($0.offset)", text: $0.element, recording: nil)
    }
    static func choose(excluding previous: String? = nil) -> ClickDialogue? {
        all.filter { $0.id != previous }.randomElement()
    }
}

private extension URL {
    var existingFile: URL? { FileManager.default.fileExists(atPath: path) ? self : nil }
}

/// One local player replaces the current utterance on every click. No audio leaves the Mac.
final class RecordedVoicePlayer: NSObject, AVAudioPlayerDelegate {
    private let startPlayback: (AVAudioPlayer) -> Bool
    private let idleStatus: String
    init(idleStatus: String = "클릭하면 14개 대사 중 하나를 보여줘요",
         startPlayback: @escaping (AVAudioPlayer) -> Bool = { $0.play() }) {
        self.idleStatus = idleStatus
        self.startPlayback = startPlayback
        super.init()
    }
    private(set) var player: AVAudioPlayer?
    private(set) var currentID: String?
    var onStatus: ((String) -> Void)?
    var isPlaying: Bool { player?.isPlaying ?? false }
    static func volume(_ value: Double) -> Float { value.isFinite ? Float(min(1, max(0, value))) : 0.65 }

    @discardableResult
    func play(_ line: RecordedLine, volume: Double) -> Bool {
        stop()
        guard let url = line.resourceURL else {
            onStatus?("녹음 파일을 찾을 수 없어요"); return false
        }
        do {
            let next = try AVAudioPlayer(contentsOf: url)
            next.delegate = self; next.volume = Self.volume(volume); next.numberOfLoops = 0
            guard next.prepareToPlay() else { onStatus?("녹음을 준비하지 못했어요"); return false }
            player = next; currentID = line.id
            guard startPlayback(next) else {
                player = nil; currentID = nil; onStatus?("소리 출력 장치를 확인해 주세요"); return false
            }
            onStatus?("재생 중 · \(line.text)")
            return true
        } catch {
            player = nil; currentID = nil; onStatus?("녹음을 재생하지 못했어요"); return false
        }
    }
    func setVolume(_ value: Double) {
        let gain = Self.volume(value)
        if player?.volume != gain { player?.volume = gain }
    }
    func stop() {
        player?.stop(); player?.delegate = nil; player = nil; currentID = nil
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.player === player else { return }
        stop(); onStatus?(flag ? idleStatus : "재생이 중단됐어요")
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard self.player === player else { return }
        stop(); onStatus?("녹음 파일을 읽지 못했어요")
    }
}
