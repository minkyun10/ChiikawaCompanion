import SwiftUI
import AppKit

private let warmInk = Color(nsColor: FriendArtwork.ink)
private let mutedInk = Color(nsColor: NSColor(hex: 0x948778))
private let cream = Color(nsColor: NSColor(hex: 0xF7F4EB))
private let blue = Color(nsColor: Friend.hachiware.color)

struct FriendPortrait: NSViewRepresentable {
    let friend: Friend
    func makeNSView(context: Context) -> PortraitView { let v = PortraitView(); v.friend = friend; return v }
    func updateNSView(_ view: PortraitView, context: Context) { view.friend = friend; view.needsDisplay = true }
}

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("DESKTOP COMPANION", systemImage: "pawprint.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2)
                Spacer()
                Text("친구들과 함께").font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(blue.opacity(0.15), in: Capsule())
            }.foregroundStyle(mutedInk)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("친구들과\n바탕화면 산책.")
                        .font(.system(size: 30, weight: .bold, design: .rounded)).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("설정 창을 닫으면, 바탕화면에서 만나요.")
                        .font(.system(size: 12)).foregroundStyle(mutedInk)
                }
                Spacer()
                Button { state.onReset?() } label: {
                    Label("모두 부르기", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .medium))
                }.buttonStyle(.plain).padding(10).background(.white.opacity(0.8), in: Capsule())
            }

            rosterCard
            chiikawaItemCard
            chiikawaLifeCard
            chiikawaVoiceCard
            ForEach(Friend.developmentRoster.filter(\.isExpansion)) { friend in
                RosterSettingsCard(state: state, friend: friend)
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("하치와레의 소품").font(.system(size: 16, weight: .semibold))
                        Text("바탕화면 소품을 발견하면 주워서 착용해요.")
                            .font(.system(size: 11)).foregroundStyle(mutedInk)
                    }
                    Spacer()
                    Button("다시 흩어 놓기") { state.onScatterItems?() }
                        .font(.system(size: 11)).buttonStyle(.bordered)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(CompanionItem.allCases) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol).font(.system(size: 20)).foregroundStyle(blue).frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).font(.system(size: 12, weight: .semibold))
                                Text(item.detail).font(.system(size: 10)).foregroundStyle(mutedInk)
                            }
                            Spacer(minLength: 0)
                            Toggle(item.name, isOn: Binding(get: { state.enabledItems.contains(item) }, set: {
                                if $0 { state.enabledItems.insert(item) } else { state.enabledItems.remove(item) }
                            })).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                                .accessibilityLabel("\(item.name) 바탕화면에 놓기")
                        }.padding(12).background(cream, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                HStack(spacing: 18) {
                    Toggle("스스로 주워 입기", isOn: $state.automaticItems)
                    Toggle("표정과 소품 동작", isOn: $state.expressive)
                }.toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
                Divider().opacity(0.5)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.equippedItem.map { "지금은 \($0.name)와 함께" } ?? "지금은 빈손으로 산책 중")
                            .font(.system(size: 11, weight: .semibold))
                        Text(state.itemStatus).font(.system(size: 10)).foregroundStyle(mutedInk)
                    }
                    Spacer()
                    Menu("주우러 가기") {
                        ForEach(CompanionItem.allCases.filter { state.enabledItems.contains($0) && state.equippedItem != $0 }) { item in
                            Button(item.name) { state.onSeekItem?(item) }
                        }
                    }.fixedSize().font(.system(size: 11))
                        .disabled(state.enabledItems.subtracting(Set([state.equippedItem].compactMap { $0 })).isEmpty)
                    Button("내려놓기") { state.onDropItem?() }.font(.system(size: 11))
                        .disabled(state.equippedItem == nil)
                }
                Text("소품이 몸에 닿으면 지나가면서도 주워요. 하치와레 위에 드래그해 건넬 수도 있어요.\n바닥에 드래그하면 옮기고, 클릭하면 주우러 와요. 새 소품을 들면 이전 것은 내려놓아요.")
                    .font(.system(size: 10)).lineSpacing(3).foregroundStyle(mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(20).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))

            dailyActionCard
            voiceCard

            sharedHomeCard

            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 20) {
                    Toggle("전체 산책", isOn: $state.roaming)
                    Spacer()
                    Toggle("모든 친구 표시", isOn: $state.showFriends)
                }.toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
            }.padding(19).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 19))

            HStack {
                Circle().fill(blue).frame(width: 6, height: 6)
                Text("각자 걷고, 각자의 소품을 주워요.")
                    .font(.system(size: 10)).foregroundStyle(mutedInk)
                Spacer()
                Text("설정은 메뉴 막대의 발바닥에서").font(.system(size: 10)).foregroundStyle(mutedInk)
            }
        }
        .padding(.horizontal, 28).padding(.top, 32).padding(.bottom, 22)
        .frame(width: 710)
        }
        .frame(width: 710, height: min(900, max(550, (NSScreen.main?.visibleFrame.height ?? 850) - 90)))
        .foregroundStyle(warmInk).background(cream).tint(Color(nsColor: NSColor(hex: 0xA79B73)))
    }

    private var rosterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Friend.developmentRoster) { friend in
                HStack(spacing: 14) {
                    FriendPortrait(friend: friend).frame(width: 72, height: 82)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(friend.name).font(.system(size: 15, weight: .semibold))
                        Text(friend == .chiikawa ? "산책 · 소품 · 공부 · 잠옷 · 집 · 한국어 음성" : "산책 · 소품 · 일상 동작 · 동굴 집")
                            .font(.system(size: 10)).foregroundStyle(mutedInk)
                    }
                    Spacer()
                    Toggle("표시", isOn: Binding(get: { state.visibleFriends.contains(friend) }, set: {
                        if $0 { state.visibleFriends.insert(friend) } else { state.visibleFriends.remove(friend) }
                    })).accessibilityLabel("\(friend.name) 표시")
                    Toggle("산책", isOn: Binding(get: { state.walkingFriends.contains(friend) }, set: {
                        if $0 { state.walkingFriends.insert(friend); state.roaming = true } else { state.walkingFriends.remove(friend) }
                    })).accessibilityLabel("\(friend.name) 산책")
                    Button("부르기") { state.onCallFriend?(friend) }.accessibilityLabel("\(friend.name) 부르기")
                }.toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
            }
            Text("마우스를 올리면 반응하고, 떼면 다시 걸어요. 클릭해 인사하거나 드래그해 옮겨 보세요.\n일반 앱 창 뒤, 바탕화면 아이콘 앞에서 함께 지내요.")
                .font(.system(size: 10)).foregroundStyle(mutedInk).lineSpacing(3)
        }.padding(20).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
    }

    private var chiikawaItemCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("치이카와의 소품", systemImage: "bag").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("다시 흩어 놓기") { state.onChiikawaScatterItems?() }.font(.system(size: 11))
            }
            LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 12) {
                ForEach(ChiikawaItem.allCases) { item in
                    HStack {
                        Label(item.name, systemImage: item.symbol).font(.system(size: 12, weight: .medium))
                        Spacer()
                        Toggle(item.name, isOn: Binding(get: { state.chiikawaItems.contains(item) }, set: {
                            if $0 { state.chiikawaItems.insert(item) } else { state.chiikawaItems.remove(item) }
                        })).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                            .accessibilityLabel("치이카와 \(item.name) 바탕화면에 놓기")
                    }.padding(12).background(cream, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            HStack {
                Toggle("스스로 주워 입기", isOn: $state.chiikawaAutomaticItems)
                    .toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
                Spacer()
                Menu("주우러 가기") {
                    ForEach(ChiikawaItem.allCases.filter { state.chiikawaItems.contains($0) && state.chiikawaEquipped != $0 }) { item in
                        Button(item.name) { state.onChiikawaSeekItem?(item) }
                    }
                }.font(.system(size: 11)).disabled(state.chiikawaItems.subtracting(Set([state.chiikawaEquipped].compactMap { $0 })).isEmpty)
                Button("내려놓기") { state.onChiikawaDropItem?() }.font(.system(size: 11)).disabled(state.chiikawaEquipped == nil)
            }
            Text(state.chiikawaEquipped.map { "지금은 \($0.name)와 함께 · \(state.chiikawaItemStatus)" } ?? state.chiikawaItemStatus)
                .font(.system(size: 10)).foregroundStyle(mutedInk)
            Text("치이카와 위에 드래그해 건네거나, 소품을 클릭해 부를 수 있어요.\n분홍 사스마타를 들고 호버하면 공격하고, 인형을 주우면 꼭 안아요. 열쇠는 귀가할 때 챙겨요.")
                .font(.system(size: 10)).foregroundStyle(mutedInk).lineSpacing(3)
        }.padding(20).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
    }

    private var sharedHomeCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("함께 쉬는 집", systemImage: "house.fill").font(.system(size: 16, weight: .semibold))
            Picker("집 디자인", selection: $state.homeStyle) {
                ForEach(HomeStyle.allCases) { style in Text(style.title).tag(style) }
            }.pickerStyle(.segmented)
            Text("집은 한 채만 표시해요. 화면 중앙 하단, Dock 위의 같은 자리에 있어요.")
                .font(.system(size: 11)).foregroundStyle(mutedInk)
            ForEach(Friend.developmentRoster) { friend in
                HStack {
                    Text(friend.name).font(.system(size: 11, weight: .semibold)).frame(width: 65, alignment: .leading)
                    if friend.isExpansion {
                        Toggle("가끔 쉬기", isOn: Binding(get: { state.options(for: friend).automaticRest }, set: { value in
                            state.updateOptions(friend) { $0.automaticRest = value }
                        })).toggleStyle(.switch).controlSize(.small)
                        Button("집에 가서 자기") { state.onRosterCommand?(friend, .home) }.disabled(state.status(for: friend).resting)
                        Button("깨우기") { state.onRosterCommand?(friend, .wake) }.disabled(!state.status(for: friend).resting)
                    } else if friend == .hachiware {
                        Toggle("가끔 쉬기", isOn: $state.automaticRest).toggleStyle(.switch).controlSize(.small)
                        Spacer()
                        Button("집에 가서 자기") { state.onGoHome?() }.disabled(state.resting)
                        Button("깨우기") { state.onWake?() }.disabled(!state.resting)
                    } else {
                        Toggle("가끔 쉬기", isOn: $state.chiikawaAutomaticRest).toggleStyle(.switch).controlSize(.small)
                        Spacer()
                        Button("집에 가서 자기") { state.onChiikawaGoHome?() }.disabled(state.chiikawaResting)
                        Button("깨우기") { state.onChiikawaWake?() }.disabled(!state.chiikawaResting)
                    }
                }.font(.system(size: 11))
                Text(friend.isExpansion ? state.status(for: friend).home : friend == .hachiware ? state.homeStatus : state.chiikawaHomeStatus)
                    .font(.system(size: 10)).foregroundStyle(mutedInk)
            }
            Text("어떤 디자인이든 모든 친구가 들어가 함께 자요. 빈 집을 클릭하면 보이는 친구들이 쉬러 가요.\n입구에 데려다 놓아도 잠들고, 자는 집을 클릭하면 깨워요. 20초 쉬면 스스로 일어나요.")
                .font(.system(size: 10)).lineSpacing(3).foregroundStyle(mutedInk)
        }.padding(20).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
    }

    private var chiikawaLifeCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("치이카와의 하루",systemImage: "house").font(.system(size: 16,weight: .semibold))
            HStack {
                Toggle("분홍 공부 책상",isOn: $state.chiikawaStudyEnabled)
                Toggle("가까이 가면 행동하기",isOn: $state.chiikawaAutomaticActivities)
                Spacer()
                Button("책상으로 가기") { state.onChiikawaStudy?() }
            }.toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
            HStack {
                Toggle("치이카와 밥그릇", isOn: $state.chiikawaFoodEnabled)
                Spacer()
                Button("밥그릇으로 가기") { state.onChiikawaEat?() }
            }.toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
            HStack(spacing: 10) {
                ForEach(ChiikawaLifeAction.allCases) { action in
                    Button(action.title) {
                        if action == .study { state.onChiikawaStudy?() } else if action == .eat { state.onChiikawaEat?() } else { state.onChiikawaLife?(action) }
                    }.frame(maxWidth: .infinity).accessibilityLabel("치이카와 \(action.title)")
                }
                Button("동작 멈추기") { state.onStopChiikawaLife?() }.disabled(!state.chiikawaLifeRunning)
            }.font(.system(size: 11))
            Text(state.chiikawaLifeStatus).font(.system(size: 10)).foregroundStyle(mutedInk)
            Text("공용 집으로 귀가할 때 열쇠를 챙기고, 잠옷을 입고 이불을 덮어 쉬어요.\n책상과 밥그릇은 따로 옮길 수 있어요. 가까이 가면 공부하거나 밥을 먹어요.")
                .font(.system(size: 10)).lineSpacing(3).foregroundStyle(mutedInk)
        }.padding(20).background(.white.opacity(0.9),in: RoundedRectangle(cornerRadius: 20))
    }

    private var chiikawaVoiceCard: some View {
        VStack(alignment: .leading,spacing: 12) {
            HStack {
                Label("치이카와의 목소리",systemImage: "waveform").font(.system(size: 16,weight: .semibold))
                Spacer()
                Toggle("클릭 목소리",isOn: $state.chiikawaVoice)
                    .toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
            }
            Text("클릭하면 이주은 성우의 짧은 반응 4개 중 하나를 무작위로 들려줘요. 공부·식사·공격·기상 같은 행동에서는 소리가 나지 않아요.")
                .font(.system(size: 11)).foregroundStyle(mutedInk)
            HStack {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(blue)
                Slider(value: $state.characterVolume,in: 0...1).accessibilityLabel("친구들 목소리 음량")
                Button("치이카와 목소리 들어보기") { state.onChiikawaVoicePreview?() }
                Button("멈추기") { state.onStopChiikawaVoice?() }
            }.font(.system(size: 11))
            Text(state.chiikawaVoiceStatus).font(.system(size: 10)).foregroundStyle(mutedInk)
        }.padding(20).background(.white.opacity(0.9),in: RoundedRectangle(cornerRadius: 20))
    }

    private var dailyActionCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("하치와레의 하루", systemImage: "sun.max")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Toggle("가까이 가면 행동하기", isOn: $state.automaticActivities)
                    .toggleStyle(.switch).controlSize(.small).font(.system(size: 10))
                Button("동작 멈추기") { state.onStopDailyAction?() }
                    .font(.system(size: 11)).disabled(!state.dailyActionRunning && !state.activityJourneyRunning)
            }
            HStack(spacing: 10) {
                ForEach(ActivitySpot.allCases) { spot in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            Label(spot.name, systemImage: spot.symbol).font(.system(size: 12, weight: .semibold))
                            Spacer(minLength: 0)
                            Toggle(spot.name, isOn: Binding(get: { state.enabledActivitySpots.contains(spot) }, set: {
                                if $0 { state.enabledActivitySpots.insert(spot) } else { state.enabledActivitySpots.remove(spot) }
                            })).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                                .accessibilityLabel("\(spot.name) 바탕화면에 놓기")
                        }
                        Text("가까이 가면 \(spot.action.title)").font(.system(size: 10)).foregroundStyle(mutedInk)
                        Button(spot.visitTitle) { state.onSeekActivitySpot?(spot) }
                            .font(.system(size: 10)).disabled(!state.enabledActivitySpots.contains(spot))
                            .accessibilityLabel("하치와레 \(spot.visitTitle)")
                    }.padding(11).frame(maxWidth: .infinity)
                        .background(cream, in: RoundedRectangle(cornerRadius: 11))
                }
            }
            HStack(spacing: 10) {
                ForEach(HachiwareAction.daily, id: \.rawValue) { action in
                    Button { state.onDailyAction?(action) } label: {
                        Label(action.title, systemImage: action == .study ? "pencil.and.outline" : action == .eat ? "fork.knife" : "drop")
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain).accessibilityLabel("하치와레 \(action.title)")
                }
            }
            Text(state.dailyActionStatus).font(.system(size: 10)).foregroundStyle(mutedInk)
            Text("책상·털뭉치·밥 근처에 가면 해당 동작을 해요. 소품을 클릭하면 걸어가고, 드래그로 자리를 바꿀 수 있어요.\n한 번 행동한 곳은 멀어졌다 돌아와야 다시 반응해요. 동작 버튼이나 캐릭터 우클릭으로 바로 볼 수도 있어요.")
                .font(.system(size: 10)).foregroundStyle(mutedInk).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(20).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
    }

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("하치와레의 목소리", systemImage: "waveform")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Toggle("클릭 목소리", isOn: $state.characterVoice)
                    .toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
            }
            Text("클릭하면 음성 대사 4개와 명대사 10개, 총 14개 중 하나가 랜덤으로 나와요. 녹음이 있는 4개는 말풍선과 함께 목소리를 들려줘요.")
                .font(.system(size: 11)).foregroundStyle(mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(blue)
                Slider(value: $state.characterVolume, in: 0...1)
                    .accessibilityLabel("클릭 목소리 음량")
                Text("\(Int((state.characterVolume * 100).rounded()))%")
                    .font(.system(size: 11).monospacedDigit()).frame(width: 36)
                Button("목소리 들어보기") { state.onVoicePreview?() }
                    .font(.system(size: 11)).accessibilityLabel("하치와레 목소리 들어보기")
                Button("멈추기") { state.onStopCharacterVoice?() }.font(.system(size: 11))
            }
            Text(state.voiceStatus).font(.system(size: 10)).foregroundStyle(mutedInk)
            Text("손정민 성우 녹음: 초밥이다! · 엉망진창으로 뒤섞였어 · 맛있다! · 그래서 말이야\n명대사 10개는 글로 보여줘요.")
                .font(.system(size: 10)).lineSpacing(3).foregroundStyle(mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(20).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
    }

    private func feature(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(blue).font(.system(size: 14)).frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 10)).foregroundStyle(mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
