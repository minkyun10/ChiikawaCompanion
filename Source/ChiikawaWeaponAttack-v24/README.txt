치이카와 무기 호버 공격 v24
작성: 2026-10-20
적용 앱: 0.14.1 (27)

동작
  치이카와가 분홍 사스마타를 든 상태에서 마우스를 올리면 공격합니다.
  하치와레의 frame count·cycle duration·frame selector를 그대로 공유하므로,
  12프레임을 순서대로 1.2초마다 반복하며 새 호버는 첫 프레임부터 시작합니다.
  마우스를 떼면 다음 60Hz 갱신에서 공격을 지우고 거리 기반 산책으로 돌아갑니다.
  걷기 정지 설정은 유지하며 클릭 말풍선·드래그가 공격보다 우선합니다.
  빈손·포셰트 장착·표정 동작 끄기·무기 표시 해제 상태에서는 공격하지 않습니다.
  하치와레의 음성·공부·집·소품과 치이카와 소품 좌표는 별도로 유지합니다.

그림
  사용자 제공 hachiware-4.jpg의 왼쪽 치이카와를 공격 표정·자세 레퍼런스로 사용했습니다.
  둥근 귀, 힘준 눈썹과 미간의 짧은 주름, 뜬 눈, 볼의 분홍 사선, 혀가 보이는
  열린 입을 반영했습니다. 연결된 양팔로 분홍 사스마타 하나를 잡습니다.
  준비 → 살짝 웅크림 → 당겨 준비 → 휘두르기/내지르기 → 뻗기 → 복귀 순서입니다.
  공격 그림에 무기가 포함되어 일반 산책용 소품 도형을 중복 표시하지 않습니다.
  기존 31개 이미지·목소리·목록 리소스는 모두 byte 단위로 동일합니다.

자료 보관
  References: 사용자 공격 이미지와 기존 v22 모델 시트 사본.
  Generated: 내장 image_gen 도구가 만든 원본 PNG 2장. 첫 시안의 무기 끝 여백 문제를
    두 번째 편집에서 보정했습니다. 채택하지 않은 첫 원본도 보존합니다.
  Prompts: 실제 사용한 최초 생성·여백 보정 프롬프트 원문.
  generations.json: 각 생성의 입력 자료·원본 파일명·SHA-256.
  PrepareAttackAtlas.swift: 진짜 alpha gutter에서 4×3 셀을 분리하고 흰 몸의 연결 영역을
    기준으로 머리 크기·몸 중심·발 기준선 26px를 등록하는 도구입니다.
    그림 픽셀과 alpha를 그대로 사용하며 배경 제거·대체나 색상 키잉을 하지 않습니다.
  Iterations/02-registered: 선택 원본에서 등록한 최초 개별 256×256 PNG 12장·atlas·등록 보고서.
  Final: 적용한 자료 사본. 6×2 atlas 1536×512, 위에서 아래·왼쪽부터 시간 순서입니다.
  Review/chiikawa-attack-frames-v24.png: 실제 FriendArtwork가 그린 번호별 12프레임 검토본.
  Review/chiikawa-hover-attack-v24.gif: 같은 renderer의 1.2초 연속 재생 미리보기.
  Review/app-settings-v24.png: 업데이트한 Mac 앱을 다시 실행해 확인한 설정 화면.

검증
  self-test-cli.txt: CLI 검사 264개 통과.
  self-test-app.txt: 앱 번들 검사 271개 통과.
  VerifyAssets.swift는 저장된 atlas·개별 PNG·GIF를 다시 읽고 시간 순서, 투명 경계,
    그림의 연결, 전체 길이 등 52개 항목을 독립적으로 검사합니다. asset-verification.json 참조.
    생성 gutter의 미세한 alpha를 유지하며, 테두리에 4% 이상 불투명한 픽셀이 없는지 확인합니다.
  existing-resources-preserved.json: 기존 31개 리소스 SHA-256과 새 atlas 원본 일치 확인.
  strict codesign 검증 통과. 외부 API나 권한 추가 없이 동작합니다.

재현
  swiftc -O Source/ChiikawaWeaponAttack-v24/PrepareAttackAtlas.swift -o .build/PrepareChiikawaAttack-v24
  .build/PrepareChiikawaAttack-v24 Source/ChiikawaWeaponAttack-v24/Generated/attack-original-v2.png <새 출력 폴더>
  bash scripts/build.sh
  build/ChiikawaCompanion.app/Contents/MacOS/ChiikawaCompanion --self-test
  swiftc -O Source/ChiikawaWeaponAttack-v24/VerifyAssets.swift -o .build/VerifyChiikawaAttack-v24
  .build/VerifyChiikawaAttack-v24 Source/ChiikawaWeaponAttack-v24
