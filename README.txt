치이카와 데스크톱 — 개인용 Mac 앱
현재 버전: 0.27.0 / build 55 (2026-10-23)
자동 검수: app bundle 949개 통과 (변신·확대 검사 65개 포함). 새 빌드 실행 완료.
실제 바탕화면의 5회 클릭·30초 복귀 육안 확인은 미확인입니다. 상세: Source/MonsterAutoReturn-v54/Audit.

사용법
  메뉴 막대의 발바닥 → 친구 소환… → 캐릭터별 소환 스위치.
  목록의 캐릭터를 누르면 옵션은 2개입니다.
  • 아이템: 그 캐릭터의 모든 소품을 한 번에 켜거나 끕니다. 책상·밥그릇도 함께 적용합니다.
  • 목소리 듣기: 등록된 실제 녹음을 재생합니다. 녹음이 없는 친구는 버튼이 비활성화됩니다.
  캐릭터 우클릭에도 같은 2개만 표시합니다.
  캐릭터를 클릭하면 기존 음성/문구 반응, 마우스를 올리면 리액션, 드래그하면 이동합니다.
  소품을 클릭하면 걸어오고, 몸 위로 드래그하면 즉시 건넵니다. 소품 좌표는 캐릭터와 독립적입니다.
  집을 클릭하면 친구들이 걸어와 쉬고, 자는 중에 클릭하면 함께 깨어납니다.
  집 그림을 우클릭하면 하치와레 집/치이카와 집을 선택합니다. 화면에는 공용 집 1개만 표시합니다.
  하치와레를 10초 안에 5번 클릭하면 꿈속의 '강해진 하치와레'로 변신합니다.
  괴물 모습은 기존 표시 크기의 가로·세로 각각 10배(1,320×1,500pt)로 커집니다.
  화면보다 큰 부분은 화면 경계 밖으로 이어집니다. 확대와 축소는 같은 지면 접점을 기준으로 650ms 동안 진행합니다.
  이동·소품·집의 좌표는 기존 발밑 기준을 유지하고, 보행 주기는 확대된 보폭에 맞춰 실제 이동거리와 연결합니다.
  5번째 클릭부터 30초가 지나면 650ms에 걸쳐 원래 모습으로 돌아옵니다.
  변신 중 클릭은 기존 음성/문구로 반응하며, 복귀 시각을 연장하거나 즉시 원복하지 않습니다.
  자동 복귀는 소리나 말풍선을 만들지 않으며 걷기·공격·수면과 소품 좌표를 유지합니다.
  하치와레를 드래그하거나 다른 캐릭터를 클릭하면 진행 중인 클릭 횟수는 초기화됩니다.
  변신 중에도 산책·소품·호버·공부·식사·토하기·공용 집 수면은 하치와레와 같은 방식으로 동작합니다.
  앱을 다시 시작하면 일반 하치와레로 시작합니다. 변신 때문에 소환 목록이나 옵션은 늘어나지 않습니다.

캐릭터와 소품
  하치와레: 카메라, 기타, 파란 사스마타, 책상, 털뭉치, 밥그릇.
  치이카와: 곰 포셰트, 분홍 사스마타, 집 열쇠, 갈색 인형, 공부 책상, 분홍 밥그릇.
  우사기: 노란 토벌봉, 푸딩.
  쿠리만쥬: 간식과 컵.
  모몽가: 벚꽃.
  랏코: 딸기 파르페, 검과 칼집. 평소에는 등에 메고, 무기 장착 상태로 호버하면 검을 꺼내 휘두릅니다.
  시사: 라멘 서빙하기.
  카니(古本屋): 책 읽기.
  무기는 하치와레·치이카와·우사기·랏코만 사용하며, 든 상태로 호버하면 공격합니다.
  랏코의 기존 아이템 스위치는 파르페와 검을 함께 제어합니다. 다른 캐릭터는 랏코의 검을 받을 수 없습니다.
  이전 설정에서 랏코 아이템이 켜져 있었다면 검을 한 번 추가하며, 꺼둔 설정·소환 상태·음성·휴식 설정은 유지합니다.
  기타·카메라·털뭉치는 하치와레 전용. 책상·밥그릇은 하치와레와 치이카와 전용입니다.
  각자의 허용 소품·행동을 유지하며 다른 친구의 아이템은 주울 수 없습니다.

화면과 동작
  일반 앱 창 뒤, 바탕화면 아이콘 앞에 표시합니다. 전체 화면 앱 위에는 올리지 않습니다.
  각 캐릭터는 독립적으로 이동하며 호버 해제 후 다음 갱신에 걷기로 돌아갑니다.
  이동거리와 보행 위상을 연결하고 양발을 반 주기 차이로 움직입니다.
  공용 집은 Dock 위의 기존 하치와레 집 위치에 고정됩니다. 집 모양이 수면 상태를 초기화하지 않습니다.
  새로운 설정에서 소환할 때 위치 초기화를 강제로 실행하지 않습니다.
  우사기·쿠리만쥬·모몽가·랏코·시사·카니는 전용 수면 원화로 눕습니다.
  긴 귀·밤색 정수리·푸른 큰 꼬리·별과 목도리·주황 갈기·집게 장식을 각자 유지합니다.
  12프레임/3.6초의 작은 숨쉬기 루프를 미리 생성하며, 수면 중 별도의 큰 PNG decoding은 하지 않습니다.
  카카오톡 알림 연동은 제거되어 있으며 접근성/알림 읽기/API 연결을 사용하지 않습니다.

성능 (현재 Mac 측정)
  Apple M1 / 8 GB RAM / macOS 26.3 / 2× backing scale.
  8명 계속 걷기: 변경 전 평균 16.40 Hz → 변경 후 59.99 Hz.
  8명 CPU: 한 코어 기준 약 94.63% → 30.85%.
  8명 자동 아이템 행동 포함 60초: 평균 59.65 Hz, 갱신의 0.47%에서 25ms 초과 지연.
  현재 구현된 최대 8명까지 측정했습니다. 완전 무드랍이나 9명 이상을 입증한 값은 아닙니다.
  수치는 실제 AppKit 창의 앱 갱신 빈도이며 compositor-present FPS를 직접 측정한 값은 아닙니다.
  PNG 반복 압축 해제를 제거하고 원본 픽셀을 재사용합니다. 원화·색·alpha·프레임 수·이동 속도는 유지합니다.
  같은 화면/창 상태에는 불필요한 요청을 보내지 않으며, idle/표정 전환/blink의 연속 동작은 유지합니다.
  원시 측정 및 동일성 검수: Source/Performance-v46/Audit.
  v53 8명 산책 비교(일반/괴물 모습 각각 10초): 평균 59.994 / 60.000 Hz,
  두 구간 모두 25ms 초과 갱신 0건. 장시간이나 compositor-present FPS를 입증하는 값은 아닙니다.
  변신용 시트도 빌드 때 미리 생성하며 실행 중에는 압축 해제한 프레임만 선택합니다.
  v53 측정과 기존 실행 이미지 204개 hash 보존 검사: Source/MonsterTransformation-v53/Audit.

목소리
  클릭하거나 목소리 듣기를 누른 경우에만 소리가 납니다. 자동 걷기·공격·생활 동작에서는 재생하지 않습니다.
  하치와레: 녹음 4개 + 명대사 10개 중 무작위 반응. 녹음이 있는 대사만 음성이 나옵니다.
  치이카와: 실제 반응 녹음 4개.
  우사기·쿠리만쥬·모몽가: 공개 성우 character demo에서 발췌한 짧은 녹음 4개씩 + 반응 문구 10개씩.
  랏코·시사·카니: 확인된 한국어 캐릭터 녹음 미확보. 창작 반응 문구 10개로 반응합니다.
  실제 클립을 사용하며 성우 음성을 합성하거나 다른 목소리로 대체하지 않습니다.
  출처 및 구간은 Source/VoiceClips-v13, Source/ChiikawaLife-v26, 각 캐릭터 제작 폴더의 Audio 자료에 보관합니다.

데이터와 메모리
  앱 설정은 local.chiikawa.companion UserDefaults에 저장됩니다.
  소환·이동·말풍선·소품·수면은 캐릭터별 상태로 관리합니다. 실행 중 메시지나 화면을 수집하지 않습니다.
  v46의 일반 8명 RSS 샘플은 약 531 MiB였습니다. v53의 격리 benchmark에서 관찰한 peak RSS는
  일반/괴물 장면 각각 약 1,209 / 1,194 MiB입니다. 실행 환경·초기 loading·측정 수명이 달라
  이 두 측정을 동일 조건의 증가분으로 해석하지 않습니다. 반복 decoding 대신 고정 원본 픽셀을 유지합니다.
  v53의 실제 GUI 앱 일반 모습 RSS 관찰값은 약 509 MiB였습니다(화면 잠금 상태의 단일 표본).
  PNG를 한 번 압축 해제한 메모리 캐시는 고정된 캐릭터/시트 수에 따라 유지되며 시간에 비례해 늘어나지 않습니다.
  변신 판정은 단조 증가 시각·최대 4개의 대기 클릭 시각·복귀 시각 한 개만 보관하며 디스크에 저장하지 않습니다.
  캐시와 실행 상태는 앱 종료 시 해제됩니다. 실행 중 Source에 로그나 이미지를 누적하지 않습니다.
  Source의 자료와 측정 로그는 개발 중 만든 고정 파일입니다.

빌드 및 검수
  bash scripts/build.sh
  build/ChiikawaCompanion.app/Contents/MacOS/ChiikawaCompanion --self-test
  build/ChiikawaCompanion.app/Contents/MacOS/ChiikawaCompanion --self-test-monster
  build/ChiikawaCompanion.app/Contents/MacOS/ChiikawaCompanion --render-monster /tmp/monster-review
  build/ChiikawaCompanion.app/Contents/MacOS/ChiikawaCompanion --render-sleep /tmp/sleep-review
  build/ChiikawaCompanion.app/Contents/MacOS/ChiikawaCompanion --benchmark-desktop /tmp/desktop-benchmark.json
  추가 옵션: --benchmark-count 8 --benchmark-seconds 60 --benchmark-active
  괴물 모습 비교 옵션: --benchmark-monster
  benchmark는 격리된 임시 설정을 사용하며 사용자의 소환/소품 설정을 변경하지 않습니다.
  앱 경로: build/ChiikawaCompanion.app. 코드 서명은 로컬 ad-hoc 방식입니다.

제작 자료
  모든 레퍼런스·T-pose·생성 시안·prompt·최종 시트·검수 기록은 Source에 보존합니다.
  목록과 hash: Source/manifest.json. 과거 적용본은 Source/Versions에 남깁니다.
  우사기: Source/Usagi-v38, Source/UsagiIdentity-v44.
  쿠리만쥬/모몽가: Source/Kurimanju-v39, Source/Momonga-v40.
  소유 아이템 규칙: Source/HachiwareExclusiveItems-v41, Source/CoreActivitiesOnly-v42, Source/CharacterItemRules-v43.
  랏코/시사/카니: Source/NewFriends-v45 (공식 출처·T-pose·전체 원화·모션 미리보기).
  현재 성능 최적화/간소화 및 이전 README: Source/Performance-v46.
  6명 전용 수면 원화·prompt·집 안 배치 검수: Source/CharacterSleep-v47.
  괴물 하치와레 공식 레퍼런스: Source/HachiwareDreamMonster-v50.
  확정 외형·T-pose: Source/HachiwareDreamMonsterDesign-v51, Source/HachiwareDreamMonsterTPose-v52.
  변신 구현·생성 원본·부품·전체 atlas·중간 시안·GIF·검수: Source/MonsterTransformation-v53.
  30초 자동 복귀·걷기/공격/수면 회귀 검사·화면 검수: Source/MonsterAutoReturn-v54.
  괴물 모습 10배 확대·지면 접점 유지·크기 전환·호버/공격/이동 회귀 검사: Source/GiantHachiware-v56.
  랏코 검·칼집 레퍼런스 3장·native 원화·12프레임 공격·8방향 장착 미리보기·검수: Source/RakkoSword-v55.
  원본 웹 문서·전체 참고 영상은 로컬 Source에 남기고 Git에서는 제외합니다.
