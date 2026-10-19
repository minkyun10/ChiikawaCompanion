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
    @State private var permission = KakaoNotificationMonitor.hasPermission
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("DESKTOP COMPANION", systemImage: "pawprint.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2)
                Spacer()
                Text("하치와레와 먼저").font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(blue.opacity(0.15), in: Capsule())
            }.foregroundStyle(mutedInk)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("하치와레와\n바탕화면 산책.")
                        .font(.system(size: 30, weight: .bold, design: .rounded)).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("설정 창을 닫으면, 바탕화면에서 만나요.")
                        .font(.system(size: 12)).foregroundStyle(mutedInk)
                }
                Spacer()
                Button { state.onReset?() } label: {
                    Label("하치와레 부르기", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .medium))
                }.buttonStyle(.plain).padding(10).background(.white.opacity(0.8), in: Capsule())
            }

            ForEach(state.activeAssignmentIndices, id: \.self) { index in
                HStack(alignment: .center, spacing: 25) {
                    VStack(spacing: 8) {
                        FriendPortrait(friend: .hachiware).frame(width: 125, height: 150)
                        Text("하치와레").font(.system(size: 14, weight: .semibold))
                        Text("오늘도 같이 걷자!").font(.system(size: 11)).foregroundStyle(mutedInk)
                    }.frame(width: 150)
                    VStack(alignment: .leading, spacing: 14) {
                        feature("바탕화면에서만", detail: "앱 창 뒤에, 바탕화면 아이콘 앞에 있어요.", icon: "macwindow")
                        feature("화면 구석구석 산책", detail: "상하좌우로 걷고, 목적지를 바꿔요.", icon: "point.topleft.down.to.point.bottomright.curvepath")
                        feature("다가오면 반가워해요", detail: "마우스를 올려 인사하고, 드래그로 옮겨요.", icon: "cursorarrow.rays")
                        Divider().opacity(0.5)
                        Text("연결할 카톡 상대").font(.system(size: 10, weight: .medium)).foregroundStyle(mutedInk)
                        HStack(spacing: 10) {
                            TextField("알림에 표시되는 이름", text: $state.assignments[index].sender)
                                .font(.system(size: 12)).textFieldStyle(.plain)
                                .padding(10).background(cream, in: RoundedRectangle(cornerRadius: 9))
                                .accessibilityLabel("하치와레 발신자 이름")
                            Button { state.demo(.hachiware) } label: {
                                Label("알림 시연", systemImage: "play.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 12).padding(.vertical, 10)
                                    .background(blue.opacity(0.2), in: Capsule())
                            }.buttonStyle(.plain).accessibilityLabel("하치와레 알림 시연")
                        }
                    }
                }.padding(22)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(blue.opacity(0.35), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("오늘은 뭘 들고 걸을까?").font(.system(size: 16, weight: .semibold))
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

            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("하치와레의 동굴 집", systemImage: "house.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Toggle("집 표시", isOn: $state.homeEnabled)
                        .toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
                }
                Text("화면 중앙 하단, Dock 위에 있어요. 일반 앱 창 뒤에 표시돼요.")
                    .font(.system(size: 11)).foregroundStyle(mutedInk)
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(state.homeStatus).font(.system(size: 11, weight: .semibold))
                        Toggle("가끔 집에서 쉬기", isOn: $state.automaticRest)
                            .toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
                    }
                    Spacer()
                    Button("집에 가서 자기") { state.onGoHome?() }
                        .disabled(!state.homeEnabled || state.resting)
                    Button("깨우기") { state.onWake?() }.disabled(!state.resting)
                }
                Text("집을 클릭하거나 하치와레를 입구에 데려다 놓으면 이불을 덮고 자요.\n잠든 집을 클릭하면 깨워요. 20초 쉬면 스스로 일어나고, 알림이 와도 일어나요.")
                    .font(.system(size: 10)).lineSpacing(3).foregroundStyle(mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(20).background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 20) {
                    Toggle("산책하기", isOn: $state.roaming)
                    Toggle("목소리 알림", isOn: $state.voice)
                    Spacer()
                    Toggle("하치와레 표시", isOn: $state.showFriends)
                }.toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
                Divider().opacity(0.5)
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 20)).foregroundStyle(Color(nsColor: NSColor(hex: 0xB5A87C)))
                        .frame(width: 34, height: 34).background(cream, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Text("카카오톡 알림").font(.system(size: 13, weight: .semibold))
                            Text("실험 기능").font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6).padding(.vertical, 3).background(cream, in: Capsule())
                        }
                        Text(state.monitoring ? state.monitoringStatus : "상대 이름을 입력하고 알림 감지를 켜 주세요.")
                            .font(.system(size: 11)).foregroundStyle(mutedInk)
                        Text(state.lastEvent).font(.system(size: 10)).foregroundStyle(mutedInk)
                        if state.monitoring && !permission && !state.accessibilityAvailable {
                            Button("손쉬운 사용 설정 열기") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                            }.font(.system(size: 11)).buttonStyle(.link)
                        }
                    }
                    Spacer()
                    Toggle("알림 감지", isOn: Binding(get: { state.monitoring }, set: { state.setMonitoring($0) }))
                        .toggleStyle(.switch).controlSize(.small).font(.system(size: 11))
                }
                Text("지정한 상대가 보낸 알림 미리보기 내용을 말풍선에 잠깐 표시해요. 긴 내용은 생략될 수 있어요.\nMac과 카카오톡에서 알림 내용 미리보기를 켜 주세요. 내용이 숨겨져 있으면 읽을 수 없어요.\n메시지는 파일에 저장하거나 외부로 보내지 않아요. 실제 수신 테스트가 필요해요.")
                    .font(.system(size: 10)).lineSpacing(3).foregroundStyle(mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(19).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 19))

            HStack {
                Circle().fill(blue).frame(width: 6, height: 6)
                Text("지금은 하치와레 한 명과 산책해요.")
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
        .onReceive(refresh) { _ in permission = KakaoNotificationMonitor.hasPermission }
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
            Text("손정민 성우 녹음: 초밥이다! · 엉망진창으로 뒤섞였어 · 맛있다! · 그래서 말이야\n명대사 10개는 글로 보여줘요. 카톡 수신 목소리 알림은 아래에서 따로 설정해요.")
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
