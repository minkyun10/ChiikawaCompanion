import SwiftUI

struct RosterSettingsCard: View {
    @ObservedObject var state: AppState
    let friend: Friend
    private var options: RosterOptions { state.options(for: friend) }
    private var status: RosterStatus { state.status(for: friend) }
    private func binding(_ key: WritableKeyPath<RosterOptions, Bool>) -> Binding<Bool> {
        Binding(get: { state.options(for: friend)[keyPath: key] }, set: { value in state.updateOptions(friend) { $0[keyPath: key] = value } })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("\(friend.name)의 하루").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("소품 다시 놓기") { state.onRosterCommand?(friend, .scatter) }
            }
            Text("바닥의 소품을 클릭하면 걸어와요. 몸 위로 드래그해 바로 건넬 수도 있어요.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(RosterItemKind.available(for: friend)) { kind in
                    HStack {
                        Image(systemName: kind.symbol).foregroundStyle(Color(nsColor: friend.color))
                        Toggle(kind.name(for: friend), isOn: Binding(get: { options.items.contains(kind) }, set: { value in
                            state.updateOptions(friend) { if value { $0.items.insert(kind) } else { $0.items.remove(kind) } }
                        })).toggleStyle(.switch).controlSize(.mini)
                        Button("부르기") { state.onRosterCommand?(friend, .seek(kind)) }
                            .disabled(!options.items.contains(kind) || status.equipped == kind)
                            .accessibilityLabel("\(friend.name) \(kind.name(for: friend)) 주우러 가기")
                    }.font(.system(size: 11)).padding(9).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            HStack {
                Toggle("스스로 주워 입기", isOn: binding(\.automaticItems))
                Spacer()
                Text(status.equipped.map { "지금은 \($0.name(for: friend)) 들고 있어요" } ?? "빈손으로 산책 중")
                Button("내려놓기") { state.onRosterCommand?(friend, .drop) }.disabled(status.equipped == nil)
            }.font(.system(size: 11))
            Divider()
            HStack(spacing: 8) {
                Menu("직접 동작 고르기") {
                    ForEach(RosterAction.selectable, id: \.rawValue) { action in
                        Button(action == .keepsake ? friend.keepsakeActionTitle : action.title) { state.onRosterCommand?(friend, .action(action)) }
                    }
                }
                Button("동작 멈추기") { state.onRosterCommand?(friend, .stopAction) }.disabled(!status.actionRunning)
                Spacer()
                Text(status.action).foregroundStyle(.secondary)
            }.font(.system(size: 11))
            Divider()
            if !RosterRecordingCatalog.catalog(for: friend).clips.isEmpty {
            HStack {
                Toggle("클릭 목소리", isOn: binding(\.voice))
                Button("목소리 들어보기") { state.onRosterCommand?(friend, .voicePreview) }
                Button("소리 멈추기") { state.onRosterCommand?(friend, .stopVoice) }
            }.font(.system(size: 11))
            Text("클릭하면 \(friend.voiceActor) 성우 녹음 4개와 문구 10개 중 하나가 나와요.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                Text("클릭하면 창작 반응 문구 10개 중 하나를 보여줘요. 확인된 한국어 캐릭터 녹음은 아직 없어요.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Text(status.voice).font(.system(size: 10)).foregroundStyle(.secondary)
            Text("소리는 클릭하거나 들어보기 버튼을 눌렀을 때만 나와요. 음량은 아래 목소리 설정을 함께 사용해요.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }.toggleStyle(.switch).controlSize(.small).padding(20)
            .background(Color(nsColor: friend.color).opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }
}
