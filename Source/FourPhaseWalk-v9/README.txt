2026-10-19 T포즈 기반 4단계 걷기 검토본

사용자 선택: 한 발당 12프레임, 양발 전체 24프레임.
기준 원화: References/approved-tpose-turnaround.png (기존 승인 T포즈/정면/후면/탑/측면 시트).
동작 참고: References/four-phase-walk.jpg 및 반대 방향 참고 이미지.

최종 검토본
  Final/hachiware-four-phase-keyposes-v9.png — 양발의 착지·내려감·교차·올라감 8개 핵심 자세.
  Final/hachiware-side-24-frame-review-v9.png — 시간 순서대로 나열한 전체 24프레임.
  Final/hachiware-side-24-frame-sheet-v9.png — 투명 배경 6열×4행, 셀당 256×256.
  Final/hachiware-four-phase-walk-v9.gif — 좌·우 방향, 정상 속도 1.36초/주기.
  Final/hachiware-four-phase-walk-slow-v9.gif — 동작을 확인할 느린 속도 2.88초/주기.
  Final/Frames — 왼쪽 24장, 오른쪽 24장 개별 투명 PNG.

생성 방식
  내장 image_gen으로 T포즈의 외형을 유지한 몸·발·팔 원화를 분리했습니다.
  생성 원본 세 장은 Source/GeneratedOriginals에, 프롬프트는 Prompts에 모두 보존합니다.
  rig-parts-bold-v9.png의 팔다리 선 두께를 사용한 Review/02-outline-and-proportions가 최종 선택입니다.
  초기 선 두께 시안과 보정 전 검토본도 삭제하지 않고 보관했습니다.
  FourPhasePreview.swift에서 같은 발 원화와 같은 궤적을 12프레임 차이로 사용합니다.
  얼굴·몸은 한 원화를 유지하고, 몸 높이는 내려감 -5.5px / 올라감 +5.5px로 움직입니다.
  팔은 같은 쪽 발과 반대로 흔들며, 오른쪽 이동은 왼쪽 완성 프레임 전체를 반전합니다.
  지지발의 기준점은 캐릭터의 진행 거리와 상쇄되어 지면 위에서 미끄러지지 않습니다.

검증
  24개 프레임이 모두 다르고, 개별 프레임과 atlas 셀이 정확히 일치합니다.
  투명 모서리, 발의 반 주기 대칭, 주기 경계 연속성, 지지발 기준점, GIF 프레임 수와 시간을 확인했습니다.
  Final/validation.json에 수치를 기록했습니다.

재현
  swift Source/FourPhaseWalk-v9/FourPhasePreview.swift Source/FourPhaseWalk-v9/rig-parts-bold-v9.png <검토 출력 폴더>

기존 사용자 요청에 따라 시트와 GIF를 먼저 보여드리는 검토 단계입니다.
앱 리소스·걷기 재생 코드·아이템 좌표·실행 앱은 변경하지 않았습니다.
