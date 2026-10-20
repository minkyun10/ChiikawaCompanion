치이카와 — 레퍼런스와 제작 검토본 v22
작성: 2026-10-20
상태: 시트·걷기 미리보기 검토 단계. 실행 앱에는 아직 적용하지 않았습니다.

사용자와 정한 순서
  레퍼런스 수집 → T포즈·각도별 기준 시트 → 걷기 시트·GIF → 확인 후 앱 적용.
  현재는 기준 외형과 움직임을 확인할 수 있는 자료 묶음까지 완성했습니다.

빠르게 볼 자료
  Review/chiikawa-collected-references-v22.png — 실제 수집한 공식 자료 7장의 모음.
  Final/chiikawa-model-sheet-v22.png — T포즈·정면·후면·측면·대각선·탑·웃음·울음.
  Final/chiikawa-expressions-items-v22.png — 인사·웃음·울음·수줍음·가방·무기·식사·수면 핵심 자세.
  Review/chiikawa-eight-direction-walk-v22.gif — 정상 속도 8방향 걷기.
  Review/chiikawa-eight-direction-walk-slow-v22.gif — 같은 프레임을 느리게 보는 검토본.
  Review/chiikawa-cardinal-keyposes-v22.png — 상하좌우 핵심 프레임.
  Review/chiikawa-diagonal-keyposes-v22.png — 앞·뒤 대각선 핵심 프레임.

보관 위치
  References/Official: 직접 내려받은 공식 이미지 8장. 활용한 캐릭터 자료는 7장이며,
    함께 수집한 웹페이지 장식 배경 1장도 제외 이유를 적고 보존했습니다.
    원본 파일을 수정하지 않았습니다. references.json에 출처 URL·용도·크기·SHA-256을 기록합니다.
  References/Project: 기존 승인 하치와레 그림체·걷기 시트와 4단계 보행 참고 이미지 사본.
    기존 정본 경로와 해시는 project-references.json에 있습니다.
  Generated: 내장 image_gen의 원본 PNG 4장. 첫 시트, 분리 몸·팔다리,
    표정·소품 시트, 선 두께를 강화한 팔다리 원본을 모두 보존합니다.
  Prompts: 실제 사용한 생성 프롬프트 4개. generations.json에 입력 이미지와 대응시켰습니다.
  Iterations/01-native: 첫 걷기 렌더. 팔다리 선이 얇고 뒤쪽 꼬리가 겹치는 초기 시안입니다.
  Iterations/02-bold-limbs: 팔다리 외곽선을 맞추고 뒤쪽 꼬리를 보존한 선택 시안입니다.
  Final/Walk: 선택 시안의 개별 투명 PNG 192장, 방향별 24프레임 atlas 8장,
    원본에서 등록한 파츠, 핵심 자세 이미지와 정상·느린 GIF입니다.
    Raw에는 연결부 정리 전 렌더도 따로 남겨 비교할 수 있습니다.
  manifest.json: 이 폴더 안에 보관한 모든 파일의 상대 경로·크기·SHA-256입니다.

동작 규격
  8방향 모두 한 발당 12프레임, 양발 전체 24프레임입니다.
  한 방향 atlas는 6열×4행, 셀당 256×256, 위에서 아래·왼쪽에서 오른쪽 순서입니다.
  Frames는 방향명-01.png부터 -24.png까지 시간 순서입니다.
  두 발은 같은 파츠·크기·궤적을 사용하고 위상만 전체 주기의 절반만큼 다릅니다.
  얼굴과 몸은 프레임마다 새로 생성하지 않고 고정된 원화를 재사용합니다.
  오른쪽 세 방향은 조립이 끝난 왼쪽 프레임 전체를 픽셀 단위로 반전합니다.
  하치와레와 같은 62.7pt/주기, 46pt/s 기준을 사용합니다. GIF는 1.36초로 반올림했습니다.
  느린 GIF는 동작 검토용 2.88초/주기이며, 그림과 순서는 정상 GIF와 같습니다.

검증
  VerifyWalk.swift가 실제로 저장한 PNG·atlas·GIF를 다시 읽어 760개 검사를 통과했습니다.
  atlas 프레임 순서, 192장 크기·투명 모서리, 반 주기 간 머리 그림 보존,
  좌우 픽셀 반전, 24개 서로 다른 프레임, GIF 프레임 수·전체 시간,
  양발 궤적의 반 주기 대칭과 각 프레임의 팔다리 연결을 확인합니다.
  asset-verification.json과 verification-log.txt에 결과를 남겼습니다.
  existing-app-preserved.json은 기존 앱 코드·이미지·음성 리소스가 그대로임을 기록합니다.

재현
  python3 Source/Chiikawa-v22/CollectReferences.py
  swift Source/Chiikawa-v22/ReferenceBoard.swift Source/Chiikawa-v22
  swiftc -O Source/Chiikawa-v22/ChiikawaWalkPreview.swift -o .build/ChiikawaWalkPreview-v22
  .build/ChiikawaWalkPreview-v22 Source/Chiikawa-v22/Generated/chiikawa-walk-rig-v1.png Source/Chiikawa-v22/Generated/chiikawa-bold-limb-parts-v2.png <새 출력 폴더>
  swiftc -O Source/Chiikawa-v22/VerifyWalk.swift -o .build/VerifyChiikawaWalk-v22
  .build/VerifyChiikawaWalk-v22 Source/Chiikawa-v22/Final/Walk
  기존 Iterations나 Final을 덮어쓰지 말고 새 번호 폴더를 사용합니다.

다음 적용 단계와 경계
  기준 외형 검토 후 캐릭터별 그림·프레임 수·대사·목소리·집 상태를 분리해 앱에 추가합니다.
  현재 실행 코드의 포즈별 프레임 수는 하치와레 기준이므로, 새 24프레임을 그대로 읽도록 바꿔야 합니다.
  식사·수면·무기·인사 자료는 정지 핵심 자세이며, 해당 행동의 전체 애니메이션은 후속 제작 대상입니다.
  치이카와의 집 원화와 한국어 녹음은 이 자료 묶음에 포함하지 않았습니다.
  T포즈·후면·탑·대각선과 걷기 보간은 공식 설정화가 아니라 레퍼런스 기반 제작 해석입니다.
  공식 상품 사진은 표정과 소품 확인용이며, 실행용 3D 재질이나 별도 손 원으로 사용하지 않습니다.
