import SwiftUI
import AppKit

struct FriendPortrait: NSViewRepresentable {
    let friend: Friend
    func makeNSView(context: Context) -> PortraitView {
        let view=PortraitView();view.friend=friend;return view
    }
    func updateNSView(_ view: PortraitView, context: Context) {
        guard view.friend != friend else { return }
        view.friend=friend;view.needsDisplay=true
    }
}

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var selected: Friend?
    private let ink=Color(nsColor:FriendArtwork.ink)
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            if let friend=selected {
                Button {selected=nil} label: {Label("친구 목록",systemImage:"chevron.left")}
                    .buttonStyle(.plain).font(.system(size:12)).accessibilityLabel("친구 목록으로 돌아가기")
                HStack {
                    Spacer();VStack(spacing:8) {
                        FriendPortrait(friend:friend).frame(width:126,height:145)
                        Text(friend.name).font(.system(size:25,weight:.bold,design:.rounded))
                    };Spacer()
                }
                VStack(spacing:0) {
                    Toggle("아이템",isOn:Binding(get:{state.itemsEnabled(for:friend)},set:{state.setItemsEnabled($0,for:friend)}))
                        .toggleStyle(.switch).padding(20).accessibilityLabel("\(friend.name) 아이템 전체")
                    Divider().padding(.horizontal,20)
                    Button {state.previewVoice(for:friend)} label: {
                        HStack {Text("목소리 듣기");Spacer();Image(systemName:"speaker.wave.2")}
                            .contentShape(Rectangle()).padding(20)
                    }.buttonStyle(.plain).disabled(!state.hasVoice(for:friend))
                        .accessibilityLabel("\(friend.name) 목소리 듣기")
                }.background(.white,in:RoundedRectangle(cornerRadius:18))
                Text(state.hasVoice(for:friend) ? "아이템은 이 친구의 소품을 한 번에 켜고 꺼요." : "아이템은 한 번에 켜고 꺼요. 등록된 목소리는 아직 없어요.")
                    .font(.system(size:11)).foregroundStyle(.secondary)
                Spacer(minLength:0)
            } else {
                Text("친구 소환").font(.system(size:26,weight:.bold,design:.rounded))
                Text("캐릭터를 누르면 아이템과 목소리를 고를 수 있어요.")
                    .font(.system(size:12)).foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing:8) {
                        ForEach(Friend.developmentRoster) { friend in
                            HStack(spacing:8) {
                                Button {selected=friend} label: {
                                    HStack(spacing:14) {
                                        FriendPortrait(friend:friend).frame(width:52,height:61)
                                        Text(friend.name).font(.system(size:15,weight:.semibold))
                                        Spacer();Image(systemName:"chevron.right").font(.system(size:11)).foregroundStyle(.secondary)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel("\(friend.name) 옵션")
                                Toggle("소환",isOn:Binding(get:{state.isVisible(friend)},set:{state.setSummoned($0,friend:friend)}))
                                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                                    .accessibilityLabel("\(friend.name) 소환")
                            }.padding(.horizontal,15).padding(.vertical,5)
                                .background(.white,in:RoundedRectangle(cornerRadius:14))
                        }
                    }
                }
            }
        }.padding(26).frame(width:430,height:min(790,max(530,(NSScreen.main?.visibleFrame.height ?? 850)-90)))
            .foregroundStyle(ink).background(Color(nsColor:NSColor(hex:0xF7F4EB)))
            .tint(Color(nsColor:selected?.color ?? Friend.hachiware.color))
    }
}
