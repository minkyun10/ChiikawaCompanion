치이카와 상좌·상우의 손 수정 — 2026-10-21
버전 0.17.7 / build 39

요청: 발은 유지하고, 대각선 위로 걷는 손을 하치와레와 동일한 형태로 맞추기.
하치와레의 실제 상좌·상우 시트에서 보이는 짧고 둥근 손을 참고했습니다.
가까운 손은 몸통 옆에 붙은 열린 U 모양으로 만들고, 먼 손은 몸통 뒤로 숨겼습니다.
기존처럼 길게 늘어진 손이나 몸에서 떨어져 흔들리는 모양을 제거했습니다.
기존 native rig의 손 경로만 바꾸며 새 image_gen 출력은 사용하지 않았습니다.
두 방향은 모두 원래 24프레임을 유지하며 상우는 완성된 상좌의 정확한 반전입니다.
앱의 이동 속도·보행 위상·프레임 순서·재생 시간과 손 이외의 동작 코드는 유지합니다.

보존
References: 적용 전 치이카와 상좌·상우 atlas와 하치와레의 대각선 참고 atlas 원본.
Iterations/01-native: 첫 손 수정과 참고 그림이 빠졌던 첫 비교 시안·native renderer를 그대로 보존합니다.
FinalRenderer/main.swift: 기준 v22 native rig와 손 경로 수정, 기존 atlas의 손 픽셀에만 적용하는 재현 도구.
Final: 적용 atlas 2장, 개별 투명 48프레임, 파츠, 비교 PNG, 정상/느린 24프레임 GIF.
기존 Source/Chiikawa-v22와 다른 과거 기록은 수정하지 않습니다.

검증
VerifyRearHands.py는 이미지 편집 없이 저장된 PNG를 다시 읽어 비교합니다.
양 방향 48장 모두 발/아래쪽 꼬리 전체 RGBA, 머리, 몸통 중심이 원본과 정확히 같습니다.
변경 픽셀은 손 높이의 두 측면에만 있으며 팔다리의 큰 분리 조각이 없는지도 검사합니다.
시트의 시간 순서, 24개 고유 프레임, 좌우 반전, 정상 GIF 1.36초/느린 GIF 2.88초를 검사합니다.
320개 asset 검사 결과는 asset-verification.json과 로그에 있습니다.
앱 번들 검사·서명·실행 결과와 다른 리소스 보존은 validation.json을 참고합니다.

재현 (repository root에서, 기존 Final을 덮어쓰지 말고 새 출력 폴더 사용)
swift build -c release
swiftc -O Sources/ChiikawaCompanion/HachiwareSprites.swift Source/ChiikawaRearArms-v37/FinalRenderer/main.swift -o .build/ChiikawaRearArms-v37-final
.build/ChiikawaRearArms-v37-final Source/Chiikawa-v22/Generated/chiikawa-walk-rig-v1.png Source/Chiikawa-v22/Generated/chiikawa-bold-limb-parts-v2.png <새 출력 폴더>
python3 Source/ChiikawaRearArms-v37/VerifyRearHands.py
