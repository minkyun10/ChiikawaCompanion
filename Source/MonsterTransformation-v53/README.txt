후속 적용: MonsterAutoReturn-v54에서 복귀를 30초 자동 방식으로 변경했습니다.
아래는 v53 당시의 구현·검수 이력입니다.

괴물 하치와레 변신 및 애니메이션 v53
작성: 2026-10-23
적용: 앱 0.25.0 / build 52

사용법
  하치와레를 10초 안에 5번 클릭하면 강해진 하치와레로 변신한다.
  같은 조건을 다시 만족하면 원래 모습으로 돌아온다.
  다른 캐릭터 클릭 또는 하치와레 드래그는 누적 클릭을 초기화한다.
  5번째 클릭은 소모되며 6번째 클릭부터 새 묶음이다. 오래된 클릭만 rolling window에서 제외한다.
  650ms 동안 바뀌며 빠르게 다시 변신해도 현재 보이는 비율부터 이어서 전환한다.
  재실행하면 일반 모습으로 시작한다. 목소리는 기존 클릭 녹음/문구 체계를 그대로 사용한다.

기존 시스템과의 관계
  새 캐릭터를 소환하거나 새 actor/window를 만들지 않는다.
  기존 하치와레의 이동 좌표, 목적지, 실제 이동 거리 기반 WalkingGait를 그대로 사용한다.
  캐릭터 프레임과 아이템의 독립 좌표·소유권은 변신 때 바꾸지 않는다.
  호버가 끝나면 기존 갱신 주기에 산책으로 돌아간다.
  사스마타 공격은 별도 overlay와 고정 신체 scale로 표시해 축소·프레임 혼합을 막는다.
  공용 집에 들어갈 때와 수면 중에도 괴물 모습을 유지한다.

자료와 생성
  기준: Source/HachiwareDreamMonsterTPose-v52의 확정 T-pose 및 3방향 시트.
  built-in image_gen 2회로 5방향 몸통/팔/발/꼬리 cutout sheet와 전용 수면 원화를 생성했다.
  Prompts/: 사용한 전체 프롬프트.
  Generated/: 두 생성 원본. Source/GeneratedOriginals에도 원본 사본을 보존한다.
  ExtractRig.swift / Rig/: 생성 sheet의 투명 gutter에서 부품을 분리한 코드와 8개 PNG, 등록 좌표·hash.
  양발은 동일한 native foot path에 반 주기 offset을 적용한다. 무작위 frame 선택은 하지 않는다.
  팔과 다리의 몸 연결부 선만 열어 붙이며 공통 foot path와 시간은 바꾸지 않는다.

완성 프레임
  8방향 × 24프레임 = 걷기 192프레임.
  인사·웃기·놀람·줍기·카메라·기타·사스마타·공부·식사·토하기·공격: 각각 12프레임 = 132프레임.
  전용 수면의 고정된 매트 위 작은 호흡 12프레임.
  총 336프레임, 실행용 atlas 20개. 정상 캐릭터 프레임으로 대체하지 않는다.
  Final/Atlases/: 실행에 쓰이는 최종 PNG sheet.
  Review/: 8방향 PNG/GIF, 동작 PNG/GIF, 변신 GIF.
  Iterations/: 최초 렌더와 팔/뒷발 보정 중간 렌더의 전체 산출물.

구현 정본
  Sources/ChiikawaCompanion/HachiwareTransformation.swift: 5회/10초 단조 시계 판정과 전환 상태.
  Sources/ChiikawaCompanion/HachiwareMonster.swift: cutout rig, 공통 보행, 액션, atlas 로딩.
  Sources/ChiikawaCompanion/MonsterExport.swift: 빌드용 atlas와 검토 GIF 출력.
  Sources/ChiikawaCompanion/MonsterChecks.swift: 클릭 경계·원복·좌표·그림·공격·집 회귀 검사.

검수
  Audit/monster-checks-cli.log: 개발 실행 파일의 괴물 기능 검사 35개 통과.
  Audit/packaged-self-test.log: 완성 app bundle 전체 검사 891개 통과.
  Audit/resource-preservation.json: 기존 활성 실행 리소스 204개 hash 동일.
  27개 역사적 보관 파일은 이전 build script부터 제거하던 retired asset이라 실행 묶음에서 제외된다.
  Audit/benchmark-eight-normal.json 및 benchmark-eight-monster.json:
    8명 산책 10초씩, 평균 59.994 / 60.000 Hz, 25ms 초과 갱신 각 0건.
    실제 AppKit 창의 main-loop와 displayIfNeeded 비용이며 compositor-present FPS 측정은 아니다.
  Audit/memory-eight-*.json: 격리 benchmark process의 RSS 관찰, peak 약 1,209 / 1,194 MiB.
  Audit/live-app-memory.json: 실제 GUI 앱 일반 모습의 단일 RSS 관찰값. 화면 잠금 상태이며 benchmark peak와 다른 지표다.
  실제 바탕화면 육안 검수는 Mac 잠금으로 아직 수행하지 못했다. 해제 후 별도로 확인한다.

데이터
  앱 실행 중 PNG 생성·다운로드·네트워크·외부 API·마이크·화면 수집은 하지 않는다.
  준비된 atlas를 한 번 decode해 사용하며, 클릭 시각 대기열은 최대 4개이고 파일로 저장하지 않는다.
  기존 캐릭터 8명과 메뉴·클릭 음성·아이템 소유 정책은 유지한다.
