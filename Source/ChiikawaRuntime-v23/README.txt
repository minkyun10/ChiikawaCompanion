치이카와 실행 적용 v23
작성: 2026-10-20
앱 버전: 0.14.0 (26)

적용 범위
  v22에서 준비한 8방향 각 24프레임 걷기 atlas 8장과 웃음·울음 alpha 원화 2장을
  변경 없이 실행 Resources로 복사했습니다. 원본 출처·SHA-256은 resource-provenance.json에 있습니다.
  기존 하치와레 이미지·음성 리소스 21개는 바이트 단위로 동일함을 확인했습니다.
  이번 작업은 새 AI 이미지 생성 없이 기존 원화 재사용과 native 도형 구현으로 진행했습니다.

사용법
  두 친구가 동시에 걷고, 각자의 위치·걷기 위상·말풍선·아이템을 유지합니다.
  설정에서 표시·산책을 친구별로 조절하고, 한 명만 다시 부를 수 있습니다.
  치이카와는 호버하면 웃고, 떼면 다음 갱신에서 다시 걷습니다. 클릭 시 웃음/울음과
  짧은 반응 말풍선을 무작위 표시하며 직전 반응을 반복하지 않습니다.
  말풍선은 약 4초 유지하고, 드래그를 시작하면 그 캐릭터의 말풍선만 닫습니다.
  분홍 포셰트와 사스마타는 공식 상품 참고 자료를 바탕으로 자체 도형으로 그렸습니다.
  소품 클릭 방문·드래그 이동·캐릭터 몸 위 드롭·몸 접촉 줍기·교체·내려놓기를 지원합니다.
  자동 교체 최소 3초, 내려놓은 같은 소품 12초, 자동 탐색 간격 24초는 공통 규칙입니다.
  각 캐릭터의 소품은 서로 다른 inventory와 화면 좌표를 가지며 다른 캐릭터에게 장착되지 않습니다.
  치이카와 우클릭에서는 산책 켜기/끄기와 소품 내려놓기를 제공합니다.
  치이카와를 클릭·드래그해도 하치와레의 음성·일상 동작·귀가·수면은 중단되지 않습니다.
  표시/산책/소품/자동 줍기 선택은 UserDefaults에 저장합니다. 위치·장착 상태는 실행 중 유지합니다.

보관 자료
  Review/chiikawa-runtime-walk-v23.gif: 앱과 같은 FriendArtwork가 실제 atlas로 렌더한 8방향 24프레임.
  Review/chiikawa-runtime-equipment-v23.png: 같은 renderer의 소품 2종×8방향과 표정 2종.
  Review의 Mac 화면은 UI 실행 확인 자료입니다. 새 파일은 루트 Source manifest에도 보관합니다.
  Iterations/01-pochette-strap은 착용 가방에 추가 고리가 보이던 첫 native 검토본을
  해당 도형 코드로 다시 렌더해 보존한 자료입니다. 최종 적용에서는 별도 고리를 제거했습니다.
  Source/Chiikawa-v22는 최초 검토 시점의 기록으로 보존하며 덮어쓰지 않았습니다.
  build-log.txt, self-test-app.txt, 검증 JSON은 실제 실행 결과입니다.

추가 자료 제작 후 진행할 부분
  치이카와 집, 한국어 성우 녹음, 공부·식사·수면·공격의 완성된 연속 모션입니다.
  v22의 해당 자료는 정지 핵심 자세이므로 전체 애니메이션처럼 연결하지 않았습니다.
  클릭 반응은 제작용 짧은 감탄사이며 공식 명대사나 성우 녹음으로 표시하지 않습니다.
  하치와레의 집·생활 동작·음성을 치이카와에 대입하지 않았습니다.

재현
  bash scripts/build.sh
  build/ChiikawaCompanion.app/Contents/MacOS/ChiikawaCompanion --self-test
  기존 v22의 독립 검증: swiftc -O Source/Chiikawa-v22/VerifyWalk.swift -o .build/VerifyChiikawaWalk-v22
  .build/VerifyChiikawaWalk-v22 Source/Chiikawa-v22/Final/Walk
